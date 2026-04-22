output "release_status" {
  description = "Helm 릴리스 상태"
  value       = helm_release.simulator.status
}

output "release_name" {
  description = "Helm 릴리스 이름"
  value       = helm_release.simulator.name
}

output "namespace" {
  description = "배포된 namespace"
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
