variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "initial_secret_value" {
  description = "Initial value for the secret"
  type        = string
  default     = "initial-secret-value-12345"
}

variable "enable_rotation" {
  description = "Enable secret rotation"
  type        = bool
  default     = true
}
