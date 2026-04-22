variable "oem_id" {
  description = "OEM 식별자 (예: hyundai, kia)"
  type        = string
}

variable "base_domain" {
  description = "기본 도메인"
  type        = string
}

variable "zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}
