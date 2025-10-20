variable "enable_provisioned_concurrency" {
  description = "Enable provisioned concurrency for the Lambda alias"
  type        = bool
  default     = false
}

variable "provisioned_concurrency" {
  description = "Provisioned concurrency units"
  type        = number
  default     = 2
}
