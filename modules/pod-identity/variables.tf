variable "role_name" {
  description = "IAM Role 이름"
  type        = string
}

variable "cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "namespace" {
  description = "ServiceAccount가 위치할 K8s namespace"
  type        = string
}

variable "service_account_name" {
  description = "K8s ServiceAccount 이름"
  type        = string
}

variable "policy_arns" {
  description = "IAM Role에 연결할 Policy ARN 목록"
  type        = list(string)
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}
