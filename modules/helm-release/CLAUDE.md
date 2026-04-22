# modules/helm-release

사용자별 Kubernetes 네임스페이스와 Helm 릴리스를 배포하는 모듈.

## Resources

- `kubernetes_namespace_v1.this`: `sim-{oem_id}-{user_id}` 네임스페이스
- `helm_release.simulator`: simulator-platform Helm 차트 릴리스

## Inputs

- `oem_id`, `user_id`: 식별자
- `helm_chart_path`: 로컬 Helm 차트 경로
- `namespace`: 대상 네임스페이스
- `ecr_registry`: ECR 레지스트리 주소
- `base_domain`: 기본 도메인
- `acm_cert_arn`: ALB Ingress용 ACM 인증서 ARN
- `hybrid_node_enabled`: Hybrid Node 스케줄링 활성화
- `simulator_*_tag`, `target_*_tag`: 컴포넌트별 이미지 태그
- `simulator_server_replicas`: 서버 레플리카 수

## Helm Set Values

Helm v3 `set = [{ name, value }]` 리스트 문법 사용. `alb.ingress.kubernetes.io/certificate-arn` 등의 dot 키는 백슬래시 이스케이프 필요.

## Notes

- `create_namespace = false`: 네임스페이스는 Terraform이 직접 생성
- `wait = false`: 이미지 준비 전 배포 허용 (초기 배포 시)
- `atomic = false`: 초기 배포 시 롤백 방지
