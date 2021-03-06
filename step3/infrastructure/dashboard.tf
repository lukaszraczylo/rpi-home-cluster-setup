## Install metrics server
module "dashboard_metrics" {
  depends_on = [kubernetes_service.traefik_svc]
  source     = "./modules/dashboard-metrics"
}

## Install dashboard
resource "helm_release" "k8s_dashboard" {
  name       = "k8s-dashboard"
  namespace  = "default"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"

  set {
    name  = "protocolHttp"
    value = "true"
  }
  set {
    name  = "ingress.enabled"
    value = "false"
  }
  set {
    name  = "rbac.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "service.externalPort"
    value = "1337"
  }
  set {
    name  = "networkPolicy.enabled"
    value = "true"
  }
  set {
    name  = "podLabels.app"
    value = "k8s-dashboard"
  }
  set {
    name  = "metrics-server.enabled"
    value = "false"
  }
  set {
    name  = "metricsScraper.enabled"
    value = "true"
  }
  set {
    name  = "metricsScraper.image.repository"
    value = "kubernetesui/metrics-scraper-arm"
  }
  set {
    name  = "metricsScraper.image.tag"
    value = "latest"
  }
}

resource "kubernetes_cluster_role_binding" "k8s_dashboard_role" {
  metadata {
    name = "kubernetes-dashboard"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "k8s-dashboard-kubernetes-dashboard"
    namespace = "default"
  }
}

# Commented out as traffic runs via traefik anyway.

# resource "kubernetes_service" "k8s_dashboard_svc" {
#   depends_on = [ kubernetes_config_map.metallb_cfg_map ]
#   metadata {
#     namespace = "default"
#     name = "dashboard"
#     annotations = {
#       "metallb.universe.tf/address-pool": "default"
#     }
#   }
#   spec {
#     port {
#       port = 80
#       target_port = 9090
#     }
#     load_balancer_ip = "192.168.50.200"
#     selector = {
#       "app.kubernetes.io/instance": "k8s-dashboard"
#     }
#     type = "LoadBalancer"
#   }
# }

resource "kubernetes_ingress" "traefik_dashboard_routing" {
  metadata {
    name = "traefik-k8s-dashboard"
    annotations = {
      "kubernetes.io/ingress.class" : "traefik"
    }
    namespace = "default"
  }

  spec {
    rule {
      host = "k8s.local"
      http {
        path {
          path = "/"
          backend {
            service_name = "k8s-dashboard-kubernetes-dashboard"
            service_port = 1337
          }
        }
      }
    }
  }
}