output "github_actions_role_arn" {
  description = "GitHub Actions IAM role ARN (from module.global)"
  value       = module.global.github_actions_role_arn
}

output "ecr_repository_arns" {
  description = "Map of ECR repository names to their ARNs"
  value       = module.global.ecr_repository_arns
}


