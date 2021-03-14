resource "helm_release" "traefik" {
  # depends_on = [ helm_release.prometheus ]
  name      = "traefik"
  namespace = "default"
  chart     = "traefik/traefik"

  set {
    name  = "deployment.replicas"
    value = "2"
  }

  set {
    name  = "service.spec.loadBalancerIP"
    value = "${var.network_subnet}.${var.net_hosts.traefik}"
  }

  values = [
    templatefile("static/traefik-static-config.tmpl", { traefik_api_key_value = var.traefik_api_key })
  ]
}

resource "kubernetes_config_map" "traefic_cfg_map" {
  metadata {
    name      = "traefik-config"
    namespace = "default"
  }
  data = {
    "traefik-config.yaml" = file("static/traefik-cfg.yaml")
  }
}

resource "kubernetes_service" "traefik_svc" {
  depends_on = [kubernetes_config_map.metallb_cfg_map, helm_release.traefik]
  metadata {
    namespace = "default"
    name      = "traefik-dashboard"
    annotations = {
      "metallb.universe.tf/address-pool" : "default"
    }
  }
  spec {
    port {
      port        = 80
      target_port = 9000
    }
    selector = {
      "app.kubernetes.io/instance" : "traefik"
    }
    type = "LoadBalancer"
  }
}
