output "secret_arn" {
  description = "ARN of the application secret"
  value       = aws_secretsmanager_secret.app_secret.arn
}

output "secret_name" {
  description = "Name of the application secret"
  value       = aws_secretsmanager_secret.app_secret.name
}

output "rotation_function_arn" {
  description = "ARN of the rotation function"
  value       = var.enable_rotation ? aws_lambda_function.rotation[0].arn : null
}
