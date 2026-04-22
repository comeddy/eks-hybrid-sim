# ============================================================
# Global
# ============================================================
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "base_domain" {
  description = "기본 도메인 (예: sim.example.com)"
  type        = string
}

variable "route53_zone_id" {
  description = "base_domain의 Route 53 Hosted Zone ID (생략 시 data source로 조회)"
  type        = string
  default     = ""
}

# ============================================================
# EKS
# ============================================================
variable "eks_cluster_name" {
  description = "EKS 클러스터 이름"
  type        = string
}

variable "ecr_registry" {
  description = "ECR 레지스트리 주소 (예: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com)"
  type        = string
}

# ============================================================
# Helm Chart 경로
# ============================================================
variable "helm_chart_path" {
  description = "simulator-platform Helm Chart 로컬 경로"
  type        = string
  default     = "../eks-simulator-helm"
}

# ============================================================
# OEM & User 정의 — 핵심 입력값
# ============================================================
variable "oem_users" {
  description = <<-EOT
    OEM별 User 목록.
    services 맵으로 서비스별 이미지 태그와 replicas를 오버라이드.
    생략된 서비스는 Helm chart의 기본값(latest, replicas=1)을 사용.

    예:
    {
      hyundai = {
        users = {
          user-a = {
            services = {
              simulator-server = { image_tag = "v1.3.0" }
              simulator-can    = { image_tag = "v1.2.0" }
            }
          }
          user-b = {}   # 모든 서비스 기본값
        }
      }
    }
  EOT
  type = map(object({
    users = map(object({
      services = optional(map(object({
        path_prefix = optional(string, "")
        image_tag   = optional(string, "latest")
        replicas    = optional(number, 1)
      })), {})
    }))
  }))
}

# ============================================================
# ALB Security Group
# ============================================================
variable "alb_security_group_id" {
  description = "ALB에 연결할 SG ID (platform/cluster에서 생성, CloudFront prefix list만 허용)"
  type        = string
  default     = ""
}

# ============================================================
# Hybrid Node
# ============================================================
variable "hybrid_node_enabled" {
  description = "Hybrid Node 스케줄링 활성화"
  type        = bool
  default     = true
}
