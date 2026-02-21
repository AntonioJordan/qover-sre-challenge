# Observability Stack

## Add repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

## Deploy
helm dependency update ./helm/observability
helm install observability ./helm/observability -n observability --create-namespace

## Access Grafana
kubectl port-forward svc/observability-grafana 3000:80 -n observability
