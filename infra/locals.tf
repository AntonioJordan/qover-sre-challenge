locals {
  mongo_hosts = var.is_dr_active ? join(",", [
    "mongo-0.mongo-headless:27017",
    "mongo-1.mongo-headless:27017",
    "mongo-2.mongo-headless:27017",
  ]) : "mongo-0.mongo-headless:27017"

  mongo_uri = "mongodb://${local.mongo_hosts}"
}
