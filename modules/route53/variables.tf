variable "oem_id" {
  description = "OEM 식별자"
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

variable "alb_dns_name" {
  description = "ALB DNS 이름 (비어있으면 레코드 생성 스킵)"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB Hosted Zone ID"
  type        = string
  default     = "ZWKZPGTI48KDX" # ap-northeast-2
}
