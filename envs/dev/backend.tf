# DEV 환경 — Root module을 참조하는 wrapper
# terraform init / plan / apply 는 이 디렉토리에서 실행합니다.

module "simulator_platform" {
  source = "../../"

  aws_region       = var.aws_region
  base_domain      = var.base_domain
  eks_cluster_name = var.eks_cluster_name
  ecr_registry     = var.ecr_registry
  helm_chart_path  = var.helm_chart_path

  hybrid_node_enabled = var.hybrid_node_enabled
  oem_users           = var.oem_users

  alb_dns_overrides = var.alb_dns_overrides
  alb_zone_id       = var.alb_zone_id
}

# --- 변수 pass-through ---
variable "aws_region"          { type = string }
variable "base_domain"         { type = string }
variable "eks_cluster_name"    { type = string }
variable "ecr_registry"        { type = string }
variable "helm_chart_path"     { type = string }
variable "hybrid_node_enabled" { type = bool }
variable "oem_users"           { type = any }
variable "alb_dns_overrides" {
  type    = map(string)
  default = null
}
variable "alb_zone_id" {
  type    = string
  default = "ZWKZPGTI48KDX"
}

# --- Outputs ---
output "user_endpoints" {
  value = module.simulator_platform.user_endpoints
}

output "acm_certificate_arns" {
  value = module.simulator_platform.acm_certificate_arns
}
