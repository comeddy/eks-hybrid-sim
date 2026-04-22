---
name: code-review
description: Terraform + Helm 코드 리뷰 — fmt, validate, lint, template 실행 후 체크리스트 기반 검토
output: "Summary, Risk (High/Medium/Low), Issues[], Suggestions[]"
---

# Code Review Skill

Terraform + Helm 코드 리뷰를 수행합니다.

## Checklist

### Terraform
- [ ] `terraform fmt` 포맷팅 준수
- [ ] `terraform validate` 통과
- [ ] `for_each` 키가 안정적인지 확인 (삭제 시 의도치 않은 재생성 방지)
- [ ] `depends_on`이 명시적으로 필요한 곳에만 사용
- [ ] 민감한 변수에 `sensitive = true` 설정
- [ ] 모듈 output이 필요한 것만 노출
- [ ] `lifecycle` 블록 적절성 검토

### Helm Chart
- [ ] `helm template` 렌더링 성공
- [ ] `helm lint` 경고 없음
- [ ] values.yaml 기본값이 안전한지 확인
- [ ] 보안 컨텍스트 (runAsNonRoot, readOnlyRootFilesystem) 설정
- [ ] 리소스 requests/limits 설정

### General
- [ ] `.tfvars` 또는 시크릿이 커밋에 포함되지 않음
- [ ] CLAUDE.md / README.md 동기화 필요 여부 확인
- [ ] 변경의 blast radius 평가 (어떤 리소스가 재생성되는지)

## Execution

```bash
cd envs/dev && terraform fmt -check -recursive ../..
cd envs/dev && terraform validate
helm lint ./eks-simulator-helm
helm template test ./eks-simulator-helm --set userId=test,oemId=test,imageRegistry=test
```
