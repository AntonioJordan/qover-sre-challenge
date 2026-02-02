resource "kubernetes_secret_v1" "mongo_auth" {
  metadata {
    name      = "mongo-auth"
    namespace = "qover"
  }

  data = {
    MONGO_INITDB_ROOT_USERNAME = var.mongo_user
    MONGO_INITDB_ROOT_PASSWORD = var.mongo_password
    MONGO_URI = "mongodb://${var.mongo_user}:${var.mongo_password}@mongo-0.mongo-headless.qover.svc.cluster.local:27017/admin"
  }

  type = "Opaque"
}
