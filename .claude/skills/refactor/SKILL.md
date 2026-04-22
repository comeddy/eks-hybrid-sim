---
name: refactor
description: Terraform 모듈 추출, 변수 통합, Helm values 재구조화 — state mv 안전 절차 포함
output: "Before/After plan diff, state migration commands, CLAUDE.md updates"
---

# Refactor Skill

Terraform 모듈 및 Helm 차트 리팩토링을 수행합니다.

## Before Refactoring

1. `terraform plan` 실행하여 현재 상태 기록
2. 변경할 리소스의 state 주소 확인: `terraform state list`
3. 리팩토링이 리소스 재생성을 유발하는지 확인

## Refactoring Patterns

### Module Extraction
- 새 모듈 디렉토리 생성 → variables.tf, main.tf, outputs.tf
- `terraform state mv` 로 기존 리소스를 새 모듈 주소로 이동
- `terraform plan` 으로 no-change 확인

### Variable Consolidation
- `oem_users` 같은 복합 변수는 `locals.tf`에서 변환
- `optional()` 함수로 기본값 제공

### Helm Values Restructuring
- `values.yaml` 키 이름 변경 시 하위 호환성 체크
- `helm diff` 로 렌더링 차이 확인

## After Refactoring

1. `terraform plan` 결과가 no-change 또는 예상된 변경만 포함
2. `helm template` 렌더링 결과 비교
3. 모듈 CLAUDE.md 업데이트
4. docs/architecture.md 반영
