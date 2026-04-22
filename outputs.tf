# ============================================================
# Outputs
# ============================================================

output "acm_certificate_arns" {
  description = "OEM별 ACM 인증서 ARN"
  value = {
    for oem_id, mod in module.acm : oem_id => mod.certificate_arn
  }
}

output "oem_domains" {
  description = "OEM별 와일드카드 도메인"
  value = {
    for oem_id in local.oem_ids : oem_id => "*.${oem_id}.${var.base_domain}"
  }
}

output "user_endpoints" {
  description = "User별 접속 URL"
  value = {
    for key, val in local.oem_user_flat :
    key => "https://${val.user_id}.${val.oem_id}.${var.base_domain}"
  }
}

output "helm_release_status" {
  description = "Helm 릴리스 상태"
  value = {
    for key, mod in module.helm_release : key => mod.release_status
  }
}

output "namespaces" {
  description = "생성된 Kubernetes namespace 목록"
  value = {
    for key, val in local.oem_user_flat :
    key => "sim-${val.oem_id}-${val.user_id}"
  }
}
