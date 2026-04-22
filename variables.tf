# ============================================================
# Global
# ============================================================
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "base_domain" {
  description = "기본 도메인 (예: example.com)"
  type        = string
  default     = "example.com"
}

variable "route53_zone_id" {
  description = "example.com 의 Route 53 Hosted Zone ID (생략 시 data source로 조회)"
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
    key = OEM ID, value = 해당 OEM의 User 설정 리스트.
    예:
    {
      hyundai = {
        users = {
          user-a = { simulator_server_tag = "v1.3.0" }
          user-b = {}
        }
      }
      kia = {
        users = {
          user-a = {}
        }
      }
    }
  EOT
  type = map(object({
    users = map(object({
      simulator_can_tag     = optional(string, "latest")
      simulator_server_tag  = optional(string, "latest")
      simulator_vehicle_tag = optional(string, "latest")
      target_android_tag    = optional(string, "latest")
      target_cluster_tag    = optional(string, "latest")
      simulator_server_replicas = optional(number, 1)
    }))
  }))
}

# ============================================================
# ALB (Route 53 Alias 용)
# ============================================================
variable "alb_dns_overrides" {
  description = <<-EOT
    OEM별 ALB DNS 이름 오버라이드 (2차 apply 시 사용).
    첫 배포 시 비워두면 Route 53 레코드가 생성되지 않고,
    ALB 프로비저닝 후 값을 넣으면 Alias 레코드가 생성됩니다.
    예: { hyundai = "k8s-ajthyun-xxx.ap-northeast-2.elb.amazonaws.com" }
  EOT
  type    = map(string)
  default = null
}

variable "alb_zone_id" {
  description = "ALB Hosted Zone ID (ap-northeast-2 = ZWKZPGTI48KDX)"
  type        = string
  default     = "ZWKZPGTI48KDX"
}

# ============================================================
# Hybrid Node
# ============================================================
variable "hybrid_node_enabled" {
  description = "Hybrid Node 스케줄링 활성화"
  type        = bool
  default     = true
}
