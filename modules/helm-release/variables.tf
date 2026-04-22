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

# --- 컴포넌트별 이미지 태그 ---
variable "simulator_can_tag" {
  type    = string
  default = "latest"
}

variable "simulator_server_tag" {
  type    = string
  default = "latest"
}

variable "simulator_vehicle_tag" {
  type    = string
  default = "latest"
}

variable "target_android_tag" {
  type    = string
  default = "latest"
}

variable "target_cluster_tag" {
  type    = string
  default = "latest"
}

variable "simulator_server_replicas" {
  description = "Simulator-Server 레플리카 수"
  type        = number
  default     = 1
}
