cd /d/Github-Devops/qover-sre-challenge
# --- RESET ---
minikube delete
minikube start --driver=docker --cpus=6 --memory=8192 --disk-size=40g
eval $(minikube docker-env)
kubectl get nodes

# --- INFRA ---
terraform -chdir=infra init
terraform -chdir=infra apply -auto-approve
kubectl get pods -n qover

# --- AUTH ---
U=$(kubectl get secret mongo-auth -n qover -o jsonpath='{.data.MONGO_INITDB_ROOT_USERNAME}' | base64 -d)
P=$(kubectl get secret mongo-auth -n qover -o jsonpath='{.data.MONGO_INITDB_ROOT_PASSWORD}' | base64 -d)

kubectl exec mongo-0 -n qover -- mongosh -u "$U" -p "$P" --authenticationDatabase admin --eval "rs.initiate()"

kubectl exec mongo-0 -n qover -- mongosh -u "$U" -p "$P" --authenticationDatabase admin --eval '
cfg=rs.conf();
cfg.members=[
{_id:0,host:"mongo-0.mongo-headless.qover.svc.cluster.local:27017"},
{_id:1,host:"mongo-1.mongo-headless.qover.svc.cluster.local:27017"},
{_id:2,host:"mongo-2.mongo-headless.qover.svc.cluster.local:27017"}
];
rs.reconfig(cfg,{force:true});
'

kubectl exec mongo-0 -n qover -- mongosh -u "$U" -p "$P" --authenticationDatabase admin --eval "rs.status()"

# --- BUILD ---
docker info
docker build -t qover-app:latest app

# --- DEPLOY ---
kubectl apply -f k8s/app/
kubectl rollout restart deploy/qover-app -n qover
kubectl get pods -n qover -w
# Ctrl+C cuando qover-app esté 1/1

# --- TEST---
kubectl port-forward svc/qover-app 3000:80 -n qover
curl http://127.0.0.1:3000/health
curl http://127.0.0.1:3000/metrics


# =========================
# AQUI EMPPIEZA PARA HELM OBSERVABILITY
# =========================

# --- BUILD DEPENDENCIES DEL CHART ---
winget install --id Helm.Helm -e --source winget
helm dependency build ./helm/observability

# --- INSTALAR / ACTUALIZAR STACK ---
helm upgrade --install observability ./helm/observability \
  --namespace observability \
  --create-namespace

# --- ESPERAR COMPONENTES ---
kubectl get pods -n observability -w
# Ctrl+C cuando Prometheus, Grafana, Loki y OTel estén Running

# --- VALIDAR RECURSOS CLAVE ---
kubectl get all -n observability

# --- ACCESO A GRAFANA ---
kubectl port-forward svc/observability-grafana 3001:80 -n observability

# En navegador 
http://127.0.0.1:3001
user: admin
pass: admin
