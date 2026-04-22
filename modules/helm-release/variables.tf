variable "oem_id" {
  description = "OEM 식별자"
  type        = string
}

variable "user_id" {
  description = "User 식별자"
  type        = string
}

variable "helm_chart_path" {
  description = "Helm Chart 로컬 경로"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "ecr_registry" {
  description = "ECR 레지스트리 주소"
  type        = string
}

variable "base_domain" {
  description = "기본 도메인"
  type        = string
}

variable "acm_cert_arn" {
  description = "ACM 인증서 ARN"
  type        = string
}

variable "hybrid_node_enabled" {
  description = "Hybrid Node 스케줄링 활성화"
  type        = bool
  default     = true
}

variable "alb_security_group_id" {
  description = "ALB에 연결할 Security Group ID"
  type        = string
  default     = ""
}

variable "services" {
  description = "백엔드 서비스 정의 map (services.simulator-can.image.tag 등)"
  type = map(object({
    path_prefix = string
    image_tag   = optional(string, "latest")
    replicas    = optional(number, 1)
  }))
  default = {}
}
