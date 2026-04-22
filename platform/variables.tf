variable "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "base_domain" {
  description = "기본 도메인 (External-DNS domainFilter)"
  type        = string
}
