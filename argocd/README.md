# ArgoCD 전환 가이드

기존 `sxk34/soldesk` (kustomize) → 신규 `lhk8080/soldesk-k8s` (Helm) 로 이관.

## 전환 전 체크

| 항목 | 기존 (sxk34/soldesk) | 신규 (lhk8080/soldesk-k8s) |
|---|---|---|
| Application name | `ticketing` | `ticketing-prod` |
| repoURL | `https://github.com/sxk34/soldesk.git` | `https://github.com/lhk8080/soldesk-k8s.git` |
| path | `k8s` (kustomize) | `charts/ticketing` (Helm) |
| namespace | `ticketing` | `ticketing` (동일 — 충돌 주의) |
| 이미지 태그 공급 | 수동/kustomize edit | soldesk-app CI가 `environments/prod/values.yaml` bump |

두 Application이 같은 namespace·리소스를 노리므로 **동시 존재 금지**. 반드시 기존을 먼저 제거.

## 1. 레포 인증 (private repo 인 경우에만)

soldesk-k8s 가 private 이면 ArgoCD 에 credential 등록.

```bash
kubectl -n argocd create secret generic soldesk-k8s-repo \
  --from-literal=type=git \
  --from-literal=url=https://github.com/lhk8080/soldesk-k8s.git \
  --from-literal=username=lhk8080 \
  --from-literal=password="$GITHUB_PAT"   # repo:read 권한 PAT

kubectl -n argocd label secret soldesk-k8s-repo \
  argocd.argoproj.io/secret-type=repository
```

public 이면 생략.

## 2. 기존 Application 제거

`selfHeal: true` 때문에 Application 이 살아 있으면 하위 리소스가 재생성됨 — 반드시 Application 먼저 삭제.

```bash
# finalizer 로 하위 리소스도 같이 정리됨
kubectl -n argocd delete application ticketing

# 정리 확인 (pod/deploy 가 모두 사라져야 함)
kubectl -n ticketing get all
```

하위 리소스가 잔존하면:
```bash
kubectl -n argocd patch application ticketing -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl -n ticketing delete all --all
```

## 3. 신규 Application 적용

```bash
kubectl apply -f argocd/application-prod.yaml
```

적용 후 확인:
```bash
kubectl -n argocd get application ticketing-prod -w
argocd app get ticketing-prod        # argocd CLI 사용 시
```

초기 sync 에서 각 Deployment 가 Healthy 로 전환되면 성공. values.yaml 의 `images.*.tag` 가 `latest` 로 되어 있으면 soldesk-app CI 가 bump 할 때까지 기다리거나, 수동으로 한 번 돌린다.

## 4. 롤백

Helm chart 변경으로 문제 생기면:
- `environments/prod/values.yaml` 이전 커밋으로 revert → push → ArgoCD auto-sync
- 또는 `argocd app rollback ticketing-prod <REVISION>` (History 는 `argocd app history ticketing-prod`)

## 5. staging 추가 시

1. `environments/staging/values.yaml` 생성
2. 이 디렉토리에 `application-staging.yaml` 추가 (`application-prod.yaml` 복사, `name`/valueFiles 경로 수정)
3. 동일 순서로 apply

## 체크리스트

- [ ] (private 인 경우) ArgoCD repo secret 등록
- [ ] `kubectl -n argocd delete application ticketing`
- [ ] `kubectl -n ticketing get all` → 비어 있음 확인
- [ ] `kubectl apply -f argocd/application-prod.yaml`
- [ ] ArgoCD UI 에서 Healthy/Synced 확인
- [ ] soldesk-app 에 빈 커밋 push → CI 가 values.yaml 태그 bump → ArgoCD 자동 sync 하는지 end-to-end 확인
