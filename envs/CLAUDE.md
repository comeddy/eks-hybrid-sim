# envs/

환경별 Terraform 래퍼 디렉토리.

## Pattern

각 환경 디렉토리 (예: `dev/`)는 루트 모듈(`../../`)을 참조하는 thin wrapper로, 환경별 `terraform.tfvars`와 backend 설정을 포함합니다.

## Structure

```
envs/
└── dev/
    ├── backend.tf         # source = "../../" 로 루트 모듈 참조
    └── terraform.tfvars   # 환경별 변수 (.gitignore 대상)
```

## Usage

```bash
cd envs/dev
terraform init
terraform plan
terraform apply
```

## Notes

- `terraform.tfvars`는 `.gitignore`에 포함 — `.tfvars.example`을 복사하여 사용
- 새 환경 추가 시 `envs/<env>/backend.tf` 생성 후 동일 패턴 적용
- S3 backend 활성화 시 환경별로 다른 state key 사용 필수
