resource "kubernetes_secret_v1" "mongo_auth" {
  metadata {
    name      = "mongo-auth"
    namespace = "qover"
  }

  data = {
    MONGO_INITDB_ROOT_USERNAME = base64encode(var.mongo_user)
    MONGO_INITDB_ROOT_PASSWORD = base64encode(var.mongo_password)
  }

  type = "Opaque"
}
