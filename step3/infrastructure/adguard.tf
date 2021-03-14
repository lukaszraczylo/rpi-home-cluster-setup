resource "kubernetes_storage_class" "adguard_nfs" {
  metadata {
    name = "nfs-adguard"
  }
  storage_provisioner    = "local"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
}

resource "kubernetes_namespace" "adguard_ns" {
  metadata {
    name = "adguard"
    labels = {
      app = "adguard"
    }
  }
}

resource "kubernetes_ingress" "adguard_ingress" {
  metadata {
    name = "traefik-adguard"
    annotations = {
      "kubernetes.io/ingress.class" : "traefik"
    }
    namespace = kubernetes_namespace.adguard_ns.metadata.0.name
  }

  spec {
    rule {
      host = "adguard.local"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.adguard_svc.metadata.0.name
            service_port = "adguard-http"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "adguard_svc" {
  depends_on = [kubernetes_config_map.metallb_cfg_map]
  metadata {
    namespace = kubernetes_namespace.adguard_ns.metadata.0.name
    name      = "adguard-fwd"
    annotations = {
      "metallb.universe.tf/address-pool" : "default"
    }
  }
  spec {
    port {
      name        = "adguard-dns-tcp"
      port        = 53
      target_port = 53
    }
    port {
      name        = "adguard-dns-tls"
      port        = 853
      target_port = 853
    }
    port {
      name        = "adguard-http"
      port        = 8080
      target_port = 8080
    }
    port {
      name        = "adguard-init"
      port        = 3000
      target_port = 3000
    }
    load_balancer_ip = "${var.network_subnet}.${var.net_hosts.adguard_catchall}"
    selector = {
      "app" : "adguard"
    }
    session_affinity = "ClientIP"
    type             = "LoadBalancer"
  }
}

resource "kubernetes_service" "adguard_udp_svc" {
  depends_on = [kubernetes_config_map.metallb_cfg_map]
  metadata {
    namespace = kubernetes_namespace.adguard_ns.metadata.0.name
    name      = "adguard-fwd-udp"
    annotations = {
      "metallb.universe.tf/address-pool" : "default"
    }
  }
  spec {
    port {
      name        = "adguard-dns-udp"
      port        = 53
      target_port = 53
      protocol    = "UDP"
    }
    load_balancer_ip = "${var.network_subnet}.${var.net_hosts.adguard}"
    selector = {
      "app" : "adguard"
    }
    type             = "LoadBalancer"
    session_affinity = "ClientIP"
  }
}

resource "kubernetes_persistent_volume" "adguard_shared_nfs" {
  metadata {
    name = "adguard-pv"
    labels = {
      name  = "type"
      value = "local"
    }
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    storage_class_name = kubernetes_storage_class.adguard_nfs.metadata.0.name
    access_modes       = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = var.nfs_storage.adguard
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "adguard_shared_nfs_claim" {
  metadata {
    name      = "adguard-pvc"
    namespace = kubernetes_namespace.adguard_ns.metadata.0.name
  }
  spec {
    storage_class_name = kubernetes_storage_class.adguard_nfs.metadata.0.name
    access_modes       = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.adguard_shared_nfs.metadata.0.name
  }
}

## adguard deployment

resource "kubernetes_deployment" "adguard" {
  depends_on = [kubernetes_persistent_volume_claim.adguard_shared_nfs_claim]
  metadata {
    name = "adguard"
    labels = {
      app = "adguard"
    }
    namespace = kubernetes_namespace.adguard_ns.metadata.0.name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "adguard"
      }
    }
    template {
      metadata {
        labels = {
          app = "adguard"
        }
      }

      spec {
        volume {
          name = "adguard-v-nfs"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.adguard_shared_nfs_claim.metadata.0.name
          }
        }
        container {
          name  = "adguard"
          image = "adguard/adguardhome:arm64-edge"
          port {
            container_port = 53
            protocol       = "TCP"
          }
          port {
            container_port = 53
            protocol       = "UDP"
          }
          port {
            container_port = 853
            protocol       = "TCP"
          }
          port {
            container_port = 3000
            protocol       = "TCP"
          }
          port {
            container_port = 8080
            protocol       = "TCP"
          }
          volume_mount {
            mount_path = "/opt/adguardhome/work"
            sub_path   = "work-k8s"
            name       = "adguard-v-nfs"
          }
          volume_mount {
            mount_path = "/opt/adguardhome/conf"
            sub_path   = "conf-k8s"
            name       = "adguard-v-nfs"
          }
        }
      }
    }
  }
}

resource "null_resource" "adguard_crd" {

  provisioner "local-exec" {
    when    = create
    command = "kubectl apply -f ./static/crd-adguard-traefik-udp-53.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f ./static/crd-adguard-traefik-udp-53.yaml"
  }
}