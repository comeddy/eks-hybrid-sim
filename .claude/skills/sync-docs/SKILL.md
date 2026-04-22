# Sync Docs Skill

프로젝트 문서를 코드 현재 상태와 동기화합니다.

## Sync Targets

| Source | Target | Check |
|--------|--------|-------|
| `main.tf` 모듈 블록 | `docs/architecture.md` 모듈 테이블 | 모듈 수 일치 |
| `variables.tf` | `README.md` 설정 옵션 테이블 | 변수 수 일치 |
| `values.yaml` 컴포넌트 | `README.md` 컴포넌트 테이블 | 컴포넌트 수 일치 |
| `outputs.tf` | `docs/architecture.md` outputs 섹션 | output 수 일치 |
| `docs/runbooks/*.md` | `CLAUDE.md` Operational Runbooks | 링크 유효성 |
| `modules/*/` | 각 `modules/*/CLAUDE.md` | 파일 존재 |

## Execution

```bash
# 1. Terraform 모듈 목록
grep -r 'module "' main.tf | awk -F'"' '{print $2}'

# 2. 변수 목록
grep '^variable "' variables.tf | awk -F'"' '{print $2}'

# 3. Output 목록
grep '^output "' outputs.tf | awk -F'"' '{print $2}'

# 4. Helm 컴포넌트 확인
ls eks-simulator-helm/templates/deployment-*.yaml | sed 's/.*deployment-//;s/.yaml//'

# 5. Runbook 링크 검증
for f in docs/runbooks/*.md; do
  basename "$f"
done
```

## Quality Score

각 항목별로 동기화 상태를 0-100%로 평가:
- 100%: 완전 동기화
- 50-99%: 부분 불일치 (경고)
- 0-49%: 심각한 불일치 (오류)
