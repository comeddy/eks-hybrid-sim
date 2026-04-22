output "fqdn" {
  description = "생성된 와일드카드 레코드 FQDN"
  value       = var.alb_dns_name != "" ? "*.${var.oem_id}.${var.base_domain}" : "(pending — ALB DNS 필요)"
}
