# Architecture

[![English](https://img.shields.io/badge/lang-English-blue)](#english) [![Korean](https://img.shields.io/badge/lang-한국어-green)](#한국어)

---

# English

## System Overview

The EKS Hybrid Simulator Platform automates provisioning of per-OEM, per-user vehicle simulator environments on Amazon EKS. Terraform orchestrates three module layers (ACM, Route 53, Helm Release) while a single Helm chart deploys six containerized components into isolated Kubernetes namespaces.

## Components by Layer

### Security Layer

| Component | Type | Purpose |
|-----------|------|---------|
| ACM Module | Terraform `modules/acm` | Wildcard TLS certificates per OEM (`*.{oem}.{domain}`) |
| Pod Security Context | Helm values | Non-root, read-only filesystem, drop ALL capabilities |

### Ingestion Layer

| Component | Type | Purpose |
|-----------|------|---------|
| ALB Ingress | AWS Load Balancer Controller | HTTPS entry point, OEM-shared ALB via `group.name` |
| nginx-proxy | Helm deployment | Per-user reverse proxy, Ingress backend |

### Processing Layer

| Component | Type | Purpose |
|-----------|------|---------|
| simulator-server | Helm deployment | Main simulation engine (scalable replicas) |
| simulator-can | Helm deployment | CAN bus communication simulator |
| simulator-vehicle | Helm deployment | Vehicle model simulator |

### Target Layer

| Component | Type | Purpose |
|-----------|------|---------|
| target-android | Helm deployment | Android target device emulation |
| target-cluster | Helm deployment | Cluster target workload |

### DNS / Networking Layer

| Component | Type | Purpose |
|-----------|------|---------|
| Route 53 Module | Terraform `modules/route53` | Wildcard DNS alias `*.{oem}.{domain}` → ALB |
| Kubernetes Namespace | Terraform `modules/helm-release` | Isolated `sim-{oem}-{user}` namespace per user |

### Orchestration Layer

| Component | Type | Purpose |
|-----------|------|---------|
| Root Module | Terraform `main.tf` | Orchestrates ACM → Route 53 → Helm Release |
| locals.tf | Terraform | Transforms nested `oem_users` → flat `oem/user` map |
| Environment Wrapper | Terraform `envs/dev/` | Thin wrapper with per-environment `terraform.tfvars` |

## Architecture Diagram

```
                           ┌─────────────────────────────────────────────────┐
                           │                  terraform apply                │
                           └────────┬──────────────┬──────────────┬──────────┘
                                    │              │              │
                                    ▼              │              ▼
                     ┌──────────────────────┐      │   ┌─────────────────────┐
                     │  module.acm[oem_id]  │      │   │ module.route53[oem] │
                     │  *.oem.example.com   │      │   │ A Alias → ALB       │
                     │  ACM Wildcard Cert   │      │   └─────────────────────┘
                     └──────────┬───────────┘      │              ▲
                                │ cert_arn         │              │ alb_dns
                                ▼                  ▼              │
                     ┌─────────────────────────────────────────────────────────┐
                     │           module.helm_release[oem/user]                 │
                     │  ┌─────────────────────────────────────────────────┐    │
                     │  │           Namespace: sim-{oem}-{user}           │    │
                     │  │                                                 │    │
                     │  │  ┌──────────┐  ┌───────────┐  ┌────────────┐   │    │
                     │  │  │  nginx   │  │ simulator │  │ simulator  │   │    │
                     │  │  │  proxy   │◀─│  server   │  │    can     │   │    │
                     │  │  │  :80     │  │  :8002    │  │   :8001    │   │    │
                     │  │  └────┬─────┘  └───────────┘  └────────────┘   │    │
                     │  │       │                                         │    │
                     │  │       │        ┌───────────┐  ┌────────────┐   │    │
                     │  │       │        │ simulator │  │  target    │   │    │
                     │  │  ALB ◀┘        │  vehicle  │  │  android   │   │    │
                     │  │  Ingress       │  :8003    │  │  :8004     │   │    │
                     │  │  (group:       └───────────┘  └────────────┘   │    │
                     │  │   ajt-{oem})                                   │    │
                     │  │                               ┌────────────┐   │    │
                     │  │                               │  target    │   │    │
                     │  │                               │  cluster   │   │    │
                     │  │                               │  :8005     │   │    │
                     │  │                               └────────────┘   │    │
                     │  └─────────────────────────────────────────────────┘    │
                     └─────────────────────────────────────────────────────────┘

     Internet ──▶ Route 53 (*.oem.domain) ──▶ ALB (HTTPS/443) ──▶ nginx-proxy ──▶ simulator-*
```

## Data Flow Summary

```
User Browser → Route 53 DNS → ALB (TLS via ACM) → nginx-proxy → simulator-server → simulator-can / simulator-vehicle / target-*
```

## Infrastructure Modules

| Module | Source | Purpose | Key Outputs |
|--------|--------|---------|-------------|
| `acm` | `./modules/acm` | OEM wildcard certificate + DNS validation | `certificate_arn` |
| `route53` | `./modules/route53` | Wildcard A alias → ALB | `fqdn` |
| `helm_release` | `./modules/helm-release` | Namespace + Helm release per user | `release_status` |

## Key Design Decisions

1. **Two-Phase Apply**: ALB DNS is only known after Ingress creation, requiring a second `terraform apply` with `alb_dns_overrides`. This avoids circular dependencies.
2. **OEM-Shared ALB**: All users under the same OEM share one ALB via `alb.ingress.kubernetes.io/group.name: ajt-{oemId}`, reducing cost and simplifying TLS.
3. **Flat Map Transform**: Nested `oem_users` is flattened to `oem/user` keys in `locals.tf`, enabling clean `for_each` iteration without nested loops.
4. **ACM Validation Deferred**: `aws_acm_certificate_validation` is commented out to prevent infinite waits when NS delegation is incomplete.
5. **Environment Wrapper Pattern**: `envs/dev/` is a thin wrapper referencing root module (`../../`), separating environment-specific state from shared module code.
6. **Hybrid Node Support**: Optional `nodeSelector` + toleration for EKS Hybrid Nodes, toggled by a single boolean variable.

## Operations

- [Full Deployment](runbooks/full-deployment.md)
- [Add OEM/User](runbooks/add-oem-user.md)
- [Troubleshooting](runbooks/troubleshooting.md)
- [Teardown](runbooks/teardown.md)
- [Installation Log (dev)](runbooks/installation-log-dev.md)

---

# 한국어

## 시스템 개요

EKS Hybrid Simulator Platform은 OEM별/사용자별 차량 시뮬레이터 환경을 Amazon EKS에 자동 프로비저닝합니다. Terraform이 세 가지 모듈 레이어(ACM, Route 53, Helm Release)를 오케스트레이션하고, 단일 Helm 차트가 격리된 Kubernetes 네임스페이스에 6개의 컨테이너 컴포넌트를 배포합니다.

## 레이어별 컴포넌트

### 보안 레이어

| 컴포넌트 | 타입 | 목적 |
|----------|------|------|
| ACM 모듈 | Terraform `modules/acm` | OEM별 와일드카드 TLS 인증서 (`*.{oem}.{domain}`) |
| Pod Security Context | Helm values | 비루트 실행, 읽기 전용 파일시스템, 모든 capability 제거 |

### 수신 레이어

| 컴포넌트 | 타입 | 목적 |
|----------|------|------|
| ALB Ingress | AWS Load Balancer Controller | HTTPS 진입점, OEM별 ALB 공유 (`group.name`) |
| nginx-proxy | Helm deployment | 사용자별 리버스 프록시, Ingress 백엔드 |

### 처리 레이어

| 컴포넌트 | 타입 | 목적 |
|----------|------|------|
| simulator-server | Helm deployment | 메인 시뮬레이션 엔진 (레플리카 조절 가능) |
| simulator-can | Helm deployment | CAN 버스 통신 시뮬레이터 |
| simulator-vehicle | Helm deployment | 차량 모델 시뮬레이터 |

### 타겟 레이어

| 컴포넌트 | 타입 | 목적 |
|----------|------|------|
| target-android | Helm deployment | Android 타겟 디바이스 에뮬레이션 |
| target-cluster | Helm deployment | 클러스터 타겟 워크로드 |

### DNS / 네트워킹 레이어

| 컴포넌트 | 타입 | 목적 |
|----------|------|------|
| Route 53 모듈 | Terraform `modules/route53` | 와일드카드 DNS alias `*.{oem}.{domain}` → ALB |
| Kubernetes Namespace | Terraform `modules/helm-release` | 사용자별 격리된 `sim-{oem}-{user}` 네임스페이스 |

### 오케스트레이션 레이어

| 컴포넌트 | 타입 | 목적 |
|----------|------|------|
| 루트 모듈 | Terraform `main.tf` | ACM → Route 53 → Helm Release 오케스트레이션 |
| locals.tf | Terraform | 중첩된 `oem_users` → 플랫 `oem/user` 맵 변환 |
| 환경 래퍼 | Terraform `envs/dev/` | 환경별 `terraform.tfvars` 포함 thin wrapper |

## 아키텍처 다이어그램

```
                           ┌─────────────────────────────────────────────────┐
                           │                  terraform apply                │
                           └────────┬──────────────┬──────────────┬──────────┘
                                    │              │              │
                                    ▼              │              ▼
                     ┌──────────────────────┐      │   ┌─────────────────────┐
                     │  module.acm[oem_id]  │      │   │ module.route53[oem] │
                     │  *.oem.example.com   │      │   │ A Alias → ALB       │
                     │  ACM 와일드카드 인증서│      │   └─────────────────────┘
                     └──────────┬───────────┘      │              ▲
                                │ cert_arn         │              │ alb_dns
                                ▼                  ▼              │
                     ┌─────────────────────────────────────────────────────────┐
                     │           module.helm_release[oem/user]                 │
                     │  ┌─────────────────────────────────────────────────┐    │
                     │  │         네임스페이스: sim-{oem}-{user}          │    │
                     │  │                                                 │    │
                     │  │  ┌──────────┐  ┌───────────┐  ┌────────────┐   │    │
                     │  │  │  nginx   │  │ simulator │  │ simulator  │   │    │
                     │  │  │  proxy   │◀─│  server   │  │    can     │   │    │
                     │  │  │  :80     │  │  :8002    │  │   :8001    │   │    │
                     │  │  └────┬─────┘  └───────────┘  └────────────┘   │    │
                     │  │       │                                         │    │
                     │  │       │        ┌───────────┐  ┌────────────┐   │    │
                     │  │       │        │ simulator │  │  target    │   │    │
                     │  │  ALB ◀┘        │  vehicle  │  │  android   │   │    │
                     │  │  Ingress       │  :8003    │  │  :8004     │   │    │
                     │  │  (group:       └───────────┘  └────────────┘   │    │
                     │  │   ajt-{oem})                                   │    │
                     │  │                               ┌────────────┐   │    │
                     │  │                               │  target    │   │    │
                     │  │                               │  cluster   │   │    │
                     │  │                               │  :8005     │   │    │
                     │  │                               └────────────┘   │    │
                     │  └─────────────────────────────────────────────────┘    │
                     └─────────────────────────────────────────────────────────┘

     인터넷 ──▶ Route 53 (*.oem.domain) ──▶ ALB (HTTPS/443) ──▶ nginx-proxy ──▶ simulator-*
```

## 데이터 흐름 요약

```
사용자 브라우저 → Route 53 DNS → ALB (ACM을 통한 TLS) → nginx-proxy → simulator-server → simulator-can / simulator-vehicle / target-*
```

## 인프라 모듈

| 모듈 | 소스 | 목적 | 주요 출력 |
|------|------|------|-----------|
| `acm` | `./modules/acm` | OEM 와일드카드 인증서 + DNS 검증 | `certificate_arn` |
| `route53` | `./modules/route53` | 와일드카드 A alias → ALB | `fqdn` |
| `helm_release` | `./modules/helm-release` | 사용자별 네임스페이스 + Helm 릴리스 | `release_status` |

## 핵심 설계 결정

1. **2단계 Apply**: ALB DNS는 Ingress 생성 후에만 알 수 있어 `alb_dns_overrides`를 추가한 2차 `terraform apply`가 필요합니다. 순환 의존성을 방지합니다.
2. **OEM별 ALB 공유**: 같은 OEM의 모든 사용자가 `alb.ingress.kubernetes.io/group.name: ajt-{oemId}`를 통해 하나의 ALB를 공유하여 비용을 절감하고 TLS를 단순화합니다.
3. **플랫 맵 변환**: 중첩된 `oem_users`를 `locals.tf`에서 `oem/user` 키로 평탄화하여 중첩 루프 없이 깔끔한 `for_each` 반복을 가능하게 합니다.
4. **ACM 검증 지연**: NS 위임이 완료되지 않았을 때 무한 대기를 방지하기 위해 `aws_acm_certificate_validation`을 주석 처리했습니다.
5. **환경 래퍼 패턴**: `envs/dev/`는 루트 모듈(`../../`)을 참조하는 thin wrapper로, 환경별 상태를 공유 모듈 코드에서 분리합니다.
6. **Hybrid Node 지원**: 단일 boolean 변수로 토글되는 EKS Hybrid Node용 선택적 `nodeSelector` + toleration입니다.

## 운영 문서

- [전체 배포](runbooks/full-deployment.md)
- [OEM/User 추가](runbooks/add-oem-user.md)
- [장애 진단](runbooks/troubleshooting.md)
- [리소스 정리](runbooks/teardown.md)
- [설치 로그 (dev)](runbooks/installation-log-dev.md)
