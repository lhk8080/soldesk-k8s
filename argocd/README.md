# ArgoCD 부트스트랩 가이드

이 레포는 **계정 중립** 상태로 유지된다. 계정 ID / ECR 풀 패스 / 이미지 태그 /
IRSA role ARN 등 팀원 계정마다 달라지는 값은 ArgoCD Application CR 의
`spec.source.helm.parameters` 로 런타임 주입한다.

## 구성 요소

| 위치 | 역할 |
|---|---|
| `environments/<env>/values.yaml` | 계정 중립 placeholder + 환경별 공통 오버라이드 |
| `charts/ticketing/` | Helm chart 본체 |
| (동적 생성) ArgoCD Application CR | `soldesk-infra/terraform/apply.sh` 가 terraform output 을 읽어 생성 → `kubectl apply` |

## 반복 배포 흐름

1. **인프라 부트스트랩** (`soldesk-infra/terraform/apply.sh`)
   - EKS + ArgoCD + ALB Controller + KEDA
   - Application CR 생성 (image tag 는 `seed-pending` 또는 이전 값 보존)
2. **이미지 시드 / 재배포** (`soldesk-app/scripts/seed.sh`)
   - 현재 git HEAD SHA 로 이미지 빌드 → 팀원 자기 ECR 에 push
   - `kubectl patch` 로 Application 의 `images.*.tag` parameter 갱신
   - ArgoCD 가 즉시 재동기화 → 새 SHA 이미지로 pod 교체
   - 프론트엔드 S3 sync + CloudFront 무효화

## Application 수동 조작

```bash
# 현재 사용중인 이미지 태그 확인
kubectl -n argocd get application ticketing-prod \
  -o jsonpath='{range .spec.source.helm.parameters[?(@.name=="images.was.tag")]}{.value}{end}'

# 특정 SHA 로 수동 롤백
kubectl -n argocd patch application ticketing-prod --type merge -p '
spec:
  source:
    helm:
      parameters:
        - { name: images.was.tag,    value: <이전 SHA> }
        - { name: images.worker.tag, value: <이전 SHA> }
'
kubectl -n argocd annotate application ticketing-prod \
  argocd.argoproj.io/refresh=hard --overwrite
```

ECR 에 그 SHA 이미지가 남아있어야 함. 수명 정책(lifecycle policy) 확인 필요.

## 멀티 계정 재현

팀원 B 가 자기 AWS 계정에서 동일하게 재현하려면:

```bash
# 1. 인프라
git clone <B 의 soldesk-infra>
cd soldesk-infra/terraform
./apply.sh                      # 자기 계정 ID 로 Application 생성

# 2. 앱 이미지 + 프론트엔드
git clone https://github.com/lhk8080/soldesk-app    # 공용 repo
cd soldesk-app
bash scripts/seed.sh            # 자기 계정 ECR 에 push + Application patch
```

이 레포(`soldesk-k8s`) 는 **읽기 전용** 이라 fork 불필요.
