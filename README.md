# soldesk-k8s

## 3-repo 구조

| 레포지토리명 | 책임 범위 | 링크 |
|---|---|---|
| soldesk-infra | • 테라폼 코드 전반<br>• AWS 리소스 + IAM<br>• 클러스터 운용에 필요한 애드온 (helm provider) | [github](https://github.com/lhk8080/soldesk-infra) |
| **soldesk-k8s** (이 repo) | • ArgoCD에 의해 동기화되는 대상<br>• monitoring, service app | — |
| soldesk-app | • 애플리케이션 소스 코드<br>• 이미지 빌드 & 레지스트리 푸시 지점 | [github](https://github.com/lhk8080/soldesk-app) |

## 디렉토리 구조

```
soldesk-k8s/
├── charts/
│   ├── ticketing/                  # write-api, read-api, worker-svc, backup, ingress, ESO
│   └── monitoring/                 # kube-prometheus-stack + grafana ingress
│
├── environments/                   # 환경별 values 오버라이드
│   ├── dev/  → ticketing-values.yaml
│   └── prod/ → ticketing-values.yaml, monitoring-values.yaml
│
└── argocd/                         # ArgoCD 설정 보조 (Notification ExternalSecret)
    └── argocd-notifications-externalsecret.yaml
```

## ArgoCD Application 관리 방식

- ArgoCD Application 매니페스트는 **`soldesk-infra/script/apply.sh`**에서 생성. infra apply 마지막 단계에서 `terraform output` 으로 계정별 값(ECR URL, IRSA ARN, SQS URL 등)을 주입하고 kubectl apply로 직접 등록.
- 한 번 등록된 뒤로는 ArgoCD source가 자동 sync.
- soldesk-app 의 CI가 `environments/<env>/ticketing-values.yaml` 의 `image.*.tag` 를 bump → commit → ArgoCD sync.

## 차트

| 차트 | 역할 |
|---|---|
| `charts/ticketing` | write-api / read-api / worker-svc / backup cronjob, Ingress(=ALB), ESO 연동 |
| `charts/monitoring` | kube-prometheus-stack(Prometheus + Grafana + alertmanager) + Grafana Ingress |

## 설계 결정

- **app-of-apps 미사용**: Application 이 2 개뿐(ticketing, monitoring)이라 app-of-apps 패턴이 불필요하다 판단.
- **Application 매니페스트를 k8s repo 에 두지 않음**: ECR URL · IRSA ARN 등 계정마다 달라지는 값이 들어가야 해서, 정적 yaml 로 박으면 계정별 재현성 떨어짐. apply.sh 가 런타임 주입 → 팀원별로 각자 계정에서 재현할 수 있도록 **계정 중립** 상태를 유지.
- **environments/ 분리**: 차트는 공통, 환경별 차이는 values 파일에서 조작.
