# Observability Module
# Creates CloudWatch dashboards, alarms, and logging for the deployment system

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.dashboard_name
  
  dashboard_body = jsonencode({
    widgets = [
      # System Overview
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Podinfo Multi-Target Deployment Dashboard\n**Environment:** ${var.environment} | **Region:** ${data.aws_region.current.name} | **Account:** ${data.aws_caller_identity.current.account_id}"
        }
      },
      # Lambda Metrics
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.name_prefix}-lambda"],
            ["AWS/Lambda", "Errors", "FunctionName", "${var.name_prefix}-lambda"],
            ["AWS/Lambda", "Duration", "FunctionName", "${var.name_prefix}-lambda"],
            ["AWS/Lambda", "Throttles", "FunctionName", "${var.name_prefix}-lambda"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Lambda Metrics"
          period  = 300
          stat    = "Sum"
        }
      },
      # ALB Metrics
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${var.name_prefix}-alb"],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${var.name_prefix}-alb"],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "${var.name_prefix}-alb"],
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", "${var.name_prefix}-alb"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ALB Metrics"
          period  = 300
          stat    = "Sum"
        }
      },
      # EC2 Metrics
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", "i-*"],
            ["AWS/EC2", "NetworkIn", "InstanceId", "i-*"],
            ["AWS/EC2", "NetworkOut", "InstanceId", "i-*"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "EC2 Metrics"
          period  = 300
          stat    = "Average"
        }
      },
      # Application Health
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["Podinfo/Application", "ApplicationHealth", "Environment", "${var.environment}"],
            ["Podinfo/Application", "RequestDuration", "Environment", "${var.environment}"],
            ["Podinfo/Application", "RequestCount", "Environment", "${var.environment}"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Application Health"
          period  = 300
          stat    = "Average"
        }
      },
      # Blue/Green Deployment Status
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 24
        height = 4
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", "${var.name_prefix}-blue-tg"],
            ["AWS/ApplicationELB", "TargetResponseTime", "TargetGroup", "${var.name_prefix}-green-tg"],
            ["AWS/ApplicationELB", "RequestCount", "TargetGroup", "${var.name_prefix}-blue-tg"],
            ["AWS/ApplicationELB", "RequestCount", "TargetGroup", "${var.name_prefix}-green-tg"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Blue/Green Deployment Status"
          period  = 300
          stat    = "Average"
        }
      },
      # Secrets Rotation Status
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 4
        properties = {
          metrics = [
            ["AWS/SecretsManager", "SecretRotation", "SecretName", "${var.name_prefix}-app-secret"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Secrets Rotation"
          period  = 300
          stat    = "Sum"
        }
      },
      # Correlation ID Tracking
      {
        type   = "log"
        x      = 12
        y      = 18
        width  = 12
        height = 4
        properties = {
          query   = "SOURCE '/aws/lambda/${var.name_prefix}-lambda' | fields @timestamp, @message | filter @message like /correlation_id/ | sort @timestamp desc | limit 20"
          region  = data.aws_region.current.name
          title   = "Recent Correlation IDs"
          view    = "table"
        }
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "main" {
  for_each = toset(var.log_groups)
  
  name              = each.value
  retention_in_days = 30
  
  tags = merge(var.common_tags, {
    Name = each.value
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.alarms.lambda_errors != null ? 1 : 0
  
  alarm_name          = "${var.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = var.alarms.lambda_errors.metric_name
  namespace           = var.alarms.lambda_errors.namespace
  period              = "300"
  statistic           = "Sum"
  threshold           = var.alarms.lambda_errors.threshold
  alarm_description   = "This metric monitors lambda errors"
  
  dimensions = {
    FunctionName = "${var.name_prefix}-lambda"
  }
  
  alarm_actions = [var.sns_topic_arn]
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-lambda-errors"
  })
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  count = var.alarms.ec2_cpu_high != null ? 1 : 0
  
  alarm_name          = "${var.name_prefix}-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = var.alarms.ec2_cpu_high.metric_name
  namespace           = var.alarms.ec2_cpu_high.namespace
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarms.ec2_cpu_high.threshold
  alarm_description   = "This metric monitors EC2 CPU utilization"
  
  dimensions = {
    InstanceId = "${var.name_prefix}-*"
  }
  
  alarm_actions = [var.sns_topic_arn]
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ec2-cpu-high"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_target_health" {
  count = var.alarms.alb_target_health != null ? 1 : 0
  
  alarm_name          = "${var.name_prefix}-alb-target-health"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = var.alarms.alb_target_health.metric_name
  namespace           = var.alarms.alb_target_health.namespace
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarms.alb_target_health.threshold
  alarm_description   = "This metric monitors ALB target response time"
  
  dimensions = {
    LoadBalancer = "${var.name_prefix}-alb"
  }
  
  alarm_actions = [var.sns_topic_arn]
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-alb-target-health"
  })
}

# Custom Metrics for Application Health
resource "aws_cloudwatch_metric_alarm" "application_health" {
  alarm_name          = "${var.name_prefix}-application-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApplicationHealth"
  namespace           = "Podinfo/Application"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors application health"
  
  alarm_actions = [var.sns_topic_arn]
  
  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-application-health"
  })
}

# Variables
variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "log_groups" {
  description = "List of CloudWatch log groups to create"
  type        = list(string)
}

variable "dashboard_name" {
  description = "CloudWatch dashboard name"
  type        = string
}

variable "alarms" {
  description = "Map of CloudWatch alarms to create"
  type = map(object({
    metric_name = string
    namespace   = string
    threshold   = number
  }))
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for notifications"
  type        = string
}

# Outputs
output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${var.dashboard_name}"
}

output "dashboard_arn" {
  description = "CloudWatch Dashboard ARN"
  value       = aws_cloudwatch_dashboard.main.dashboard_arn
}

output "log_group_arns" {
  description = "CloudWatch Log Group ARNs"
  value = {
    for k, v in aws_cloudwatch_log_group.main : k => v.arn
  }
}
