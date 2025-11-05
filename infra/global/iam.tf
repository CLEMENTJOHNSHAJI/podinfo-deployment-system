# infra/global/iam.tf
# Grants the GitHub Actions role permission to:
# - create a Launch Template version
# - update the Auto Scaling Group
# - pass the EC2 instance role referenced by the Launch Template (podinfo-instance-profile)

# NOTE: Do NOT re-declare data.aws_caller_identity.current or data.aws_region.current here
# because they are already defined in infra/global/main.tf

variable "launch_template_id" {
  description = "Launch Template ID used by the deployment"
  type        = string
  default     = "lt-07dcc08e5fbf1aaee"
}

variable "asg_name" {
  description = "Auto Scaling Group name to update"
  type        = string
  default     = "podinfo-asg"
}

variable "instance_role_arn" {
  description = "ARN of the EC2 instance role referenced by the Launch Template (from podinfo-instance-profile). Pass via -var or set default."
  type        = string
  default     = ""
}

locals {
  # use the data sources declared in this module (main.tf)
  launch_template_arn = "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:launch-template/${var.launch_template_id}"
  asg_arn              = "arn:aws:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.asg_name}"

  base_statements = [
    {
      Sid = "AllowLaunchTemplateVersionOperations"
      Effect = "Allow"
      Action = [
        "ec2:CreateLaunchTemplateVersion",
        "ec2:ModifyLaunchTemplate",
        "ec2:RunInstances",
        "ec2:DescribeLaunchTemplates",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetLaunchTemplateData"
      ]
      Resource = [
        "arn:aws:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:launch-template/*"
      ]
    },
    {
      Sid = "AllowAutoScalingUpdate"
      Effect = "Allow"
      Action = [
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:StartInstanceRefresh",
        "autoscaling:DescribeInstanceRefreshes"
      ]
      Resource = [
        "arn:aws:autoscaling:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/podinfo-*"
      ]
    }
  ]

  passrole_statement = var.instance_role_arn != "" ? [
    {
      Sid = "AllowPassRoleForInstanceProfile"
      Effect = "Allow"
      Action = [
        "iam:PassRole"
      ]
      Resource = [var.instance_role_arn]
    }
  ] : []
}

resource "aws_iam_role_policy" "github_actions_launch_template" {
  name = "podinfo-github-actions-launch-template"

  # Make sure this matches the role resource name defined in infra/global/main.tf
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(local.base_statements, local.passrole_statement)
  })
}
