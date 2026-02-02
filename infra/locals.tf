locals {
  mongo_replicaset = "rs0"

  mongo_hosts = var.is_dr_active ? join(",", [
    "mongo-0.mongo-headless.qover.svc.cluster.local:27017",
    "mongo-1.mongo-headless.qover.svc.cluster.local:27017",
    "mongo-2.mongo-headless.qover.svc.cluster.local:27017",
  ]) : "mongo-0.mongo-headless.qover.svc.cluster.local:27017"

  mongo_uri = var.is_dr_active ? "mongodb://${var.mongo_user}:${var.mongo_password}@${local.mongo_hosts}/?replicaSet=${local.mongo_replicaset}&authSource=admin" : "mongodb://${var.mongo_user}:${var.mongo_password}@${local.mongo_hosts}/?authSource=admin"
}
