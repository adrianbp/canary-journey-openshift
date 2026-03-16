# EKS Validation: Flagger + NGINX Controllers

Este pacote valida Flagger no EKS em duas trilhas:
1. `ingress-nginx` community (referência suportada no tutorial do Flagger)
2. `NGINX Ingress Controller F5 OSS` (compatibilidade a validar)

## Pré-requisitos
- `aws`, `kubectl`, `helm`, `eksctl`, `rg`
- credenciais AWS configuradas
- cota EC2 suficiente na região

Instalar `eksctl` (macOS):
```bash
brew install weaveworks/tap/eksctl
```

## 0) Criar cluster EKS
```bash
cp infra/eks/flagger-nginx-validation/cluster-config.example.yaml \
   infra/eks/flagger-nginx-validation/cluster-config.yaml

infra/eks/flagger-nginx-validation/create-eks-cluster.sh \
  infra/eks/flagger-nginx-validation/cluster-config.yaml
```

## Trilha A - ingress-nginx community (baseline)
```bash
infra/eks/flagger-nginx-validation/install-nginx-flagger.sh
export APP_HOST=podinfo.localtest.me
export INGRESS_CLASS=nginx
infra/eks/flagger-nginx-validation/deploy-flagger-test.sh
```

Verificação:
```bash
kubectl -n test get canary podinfo -w
kubectl -n test describe canary podinfo
kubectl -n ingress-nginx logs deploy/flagger --tail=200
```

## Trilha B - NGINX F5 OSS (foco atual)
```bash
# instala NGINX F5 + Flagger
infra/eks/flagger-nginx-validation/install-nginx-f5-flagger.sh

# ajusta classe se necessário (veja output de ingressclass)
export APP_HOST=podinfo.localtest.me
export INGRESS_CLASS=nginx
infra/eks/flagger-nginx-validation/deploy-flagger-test.sh

# coleta evidências de compatibilidade
infra/eks/flagger-nginx-validation/validate-flagger-with-f5.sh
```

## Pontos para validar na trilha F5
1. Flagger cria/atualiza objetos `Canary` sem erro.
2. Ingresses gerados têm anotações aceitas pelo controller F5.
3. Pesos canary progridem de fato no tráfego.
4. Promoção ocorre sem erro no reconcile.

## Evidências A/B
- Relatório consolidado: `infra/eks/flagger-nginx-validation/evidence/AB-EVIDENCE-2026-03-16.md`
- Gateway API + Flagger: `infra/eks/flagger-nginx-validation/evidence/GATEWAY-API-EVIDENCE-2026-03-16.md`

## Limpeza
```bash
infra/eks/flagger-nginx-validation/destroy-eks-cluster.sh \
  infra/eks/flagger-nginx-validation/cluster-config.yaml
```

## Referências
- Flagger NGINX tutorial: https://docs.flagger.app/tutorials/nginx-progressive-delivery
- Flagger deployment strategies: https://docs.flagger.app/main/usage/deployment-strategies#canary-deployments
- NGINX F5 Helm install: https://docs.nginx.com/nginx-ingress-controller/install/helm/open-source/
- Flagger repo: https://github.com/fluxcd/flagger
