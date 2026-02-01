resource "kubernetes_namespace" "qover" {
  metadata {
    name = "qover"
  }
}

resource "kubernetes_secret" "mongo_auth" {
  metadata {
    name      = "mongo-auth"
    namespace = kubernetes_namespace.qover.metadata[0].name
  }

  data = {
    MONGO_INITDB_ROOT_USERNAME = var.mongo_user
    MONGO_INITDB_ROOT_PASSWORD = var.mongo_password
    MONGO_URI                  = local.mongo_uri
  }

  type = "Opaque"
}

resource "kubernetes_secret" "mongo_keyfile" {
  metadata {
    name      = "mongo-keyfile"
    namespace = kubernetes_namespace.qover.metadata[0].name
  }

  data = {
    keyfile = "cW92ZXJsb2NhbGtleWZpbGVyYW5kb21zdHJpbmcxMjM0NTY3ODkw"
  }

  type = "Opaque"
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
  depends_on = [
    kubernetes_secret.mongo_auth,
    kubernetes_secret.mongo_keyfile
  ]

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
        security_context {
          run_as_non_root = true
          run_as_user     = 999
          fs_group        = 999
        }

        volume {
          name = "mongo-keyfile"
          secret {
            secret_name = kubernetes_secret.mongo_keyfile.metadata[0].name
          }
        }

        init_container {
          name    = "fix-keyfile-perms"
          image   = "busybox:1.36"
          command = ["sh", "-c"]
          args    = ["cp /in/keyfile /out/keyfile && chmod 0400 /out/keyfile && chown 999:999 /out/keyfile"]

          volume_mount {
            name       = "mongo-keyfile"
            mount_path = "/in"
            read_only  = true
          }

          volume_mount {
            name       = "mongo-keyfile-fixed"
            mount_path = "/out"
          }
        }

        volume {
          name = "mongo-keyfile-fixed"
          empty_dir {}
        }

        container {
          name  = "mongo"
          image = "mongo:8.0"

          args = [
            "--replSet", local.mongo_replicaset,
            "--bind_ip_all",
            "--auth",
            "--keyFile", "/etc/mongo-keyfile/keyfile"
          ]

          env_from {
            secret_ref {
              name = kubernetes_secret.mongo_auth.metadata[0].name
            }
          }

          port {
            container_port = 27017
          }

          readiness_probe {
            tcp_socket {
              port = 27017
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }

          liveness_probe {
            tcp_socket {
              port = 27017
            }
            initial_delay_seconds = 40
            period_seconds        = 20
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "768Mi"
            }
          }

          volume_mount {
            name       = "mongo-data"
            mount_path = "/data/db"
          }

          volume_mount {
            name       = "mongo-keyfile-fixed"
            mount_path = "/etc/mongo-keyfile"
            read_only  = true
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "mongo-data"
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "standard"

        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}
