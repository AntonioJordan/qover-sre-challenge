# qover-sre-challenge
SRE technical challenge: Terraform-based MongoDB StatefulSet with DR toggle, TypeScript microservice with Prometheus metrics, and GitOps deployment via ArgoCD on Kubernetes.

#-----Task 1----#

The goal was to prepare the environment and deploy MongoDB on Kubernetes using Terraform, including persistence and a disaster recovery toggle. 

I set up MongoDB locally for testing, started a local Kubernetes cluster with Minikube, and then used Terraform to provision all Kubernetes resources: a namespace, a headless service, a StatefulSet for MongoDB, a PersistentVolumeClaim template for data persistence, and a Secret containing the MongoDB connection string. 

I also implemented a variable called is_dr_active so the deployment can switch between a single MongoDB pod for development and three MongoDB replicas for DR mode, generating the connection string dynamically depending on that value.

The commands executed were the following:

docker run -d -p 27017:27017 mongo:8
minikube start
terraform init 
terraform apply

When DR mode is enabled (is_dr_active=true), the generated connection string is:

mongodb://mongo-0.mongo-headless:27017,mongo-1.mongo-headless:27017,mongo-2.mongo-headless:27017



#-----Task 2----#

In Task 2 the goal was to build a minimal TypeScript service that connects to MongoDB and exposes health, data, and Prometheus metrics endpoints. I implemented an Express app that reads the MongoDB connection string from the MONGO_URI environment variable and provides /health, /data, and /metrics endpoints, including a custom Prometheus metric to measure database query duration.

The commands executed were the following:

npm init -y  
npm install express mongodb prom-client  
npm install -D typescript @types/node @types/express  
npx tsc --init --rootDir src --outDir dist --module commonjs --target ES2020 --esModuleInterop --strict  
npm run build  

To run the application locally:

set MONGO_URI=mongodb://localhost:27017
set PORT=3001
npm start

The /metrics endpoint exposes default Node.js metrics and the custom metric mongo_query_duration_seconds, which records the duration of MongoDB queries executed by the /data endpoint.

To verify Docker:
docker build -t qover-app .
docker run -e MONGO_URI=mongodb://host.docker.internal:27017 -p 3000:3000 qover-app

To verify functionality:

curl http://localhost:3001/
curl http://localhost:3001/health
curl http://localhost:3001/data
curl http://localhost:3001/metrics

