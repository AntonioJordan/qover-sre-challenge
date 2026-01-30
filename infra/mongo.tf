resource "kubernetes_namespace" "qover" {
  metadata {
    name = "qover"
  }
}

resource "kubernetes_secret" "mongo_uri" {
  metadata {
    name      = "mongo-uri"
    namespace = kubernetes_namespace.qover.metadata[0].name
  }

  data = {
    MONGO_URI = local.mongo_uri
  }
}

resource "kubernetes_service" "mongo_headless" {
  metadata {
    name      = "mongo-headless"
    namespace = kubernetes_namespace.qover.metadata[0].name
  }

  spec {
    cluster_ip = "None"

    selector = {
      app = "mongo"
    }

    port {
      port        = 27017
      target_port = 27017
    }
  }
}

resource "kubernetes_stateful_set" "mongo" {
  metadata {
    name      = "mongo"
    namespace = kubernetes_namespace.qover.metadata[0].name
  }

  spec {
    service_name = kubernetes_service.mongo_headless.metadata[0].name
    replicas     = var.is_dr_active ? 3 : 1

    selector {
      match_labels = {
        app = "mongo"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongo"
        }
      }

      spec {
        container {
          name  = "mongo"
          image = "mongo:8.0"

          port {
            container_port = 27017
          }

          volume_mount {
            name       = "mongo-data"
            mount_path = "/data/db"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "mongo-data"
      }

      spec {
        access_modes = ["ReadWriteOnce"]

        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}
