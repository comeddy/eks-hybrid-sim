output "alb_controller_role_arn" {
  value = module.alb_controller_pod_identity.role_arn
}

output "external_dns_role_arn" {
  value = module.external_dns_pod_identity.role_arn
}

output "external_secrets_role_arn" {
  value = module.eso_pod_identity.role_arn
}
