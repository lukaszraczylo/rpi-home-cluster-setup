resource "kubernetes_storage_class" "torrent_nfs" {
  metadata {
    name = "nfs-torrent"
  }
  storage_provisioner    = "local"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
}

resource "kubernetes_namespace" "torrent_ns" {
  metadata {
    name = "torrent"
    labels = {
      app = "torrent"
    }
  }
}

resource "kubernetes_ingress" "torrent_ingress" {
  metadata {
    name = "traefik-k8s"
    annotations = {
      "kubernetes.io/ingress.class" : "traefik"
    }
    namespace = kubernetes_namespace.torrent_ns.metadata.0.name
  }

  spec {
    rule {
      host = "torrent.local"
      http {
        path {
          path = "/"
          backend {
            service_name = kubernetes_service.torrent_svc.metadata.0.name
            service_port = 3000
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "torrent_svc" {
  depends_on = [kubernetes_config_map.metallb_cfg_map]
  metadata {
    namespace = kubernetes_namespace.torrent_ns.metadata.0.name
    name      = "torrent-fwd"
    annotations = {
      "metallb.universe.tf/address-pool" : "default"
    }
  }
  spec {
    port {
      name        = "torrent-rpc"
      port        = 5000
      target_port = 5000
    }
    port {
      name        = "torrent-tcp"
      port        = 23340
      target_port = 23340
    }
    port {
      name        = "torrent-http"
      port        = 3000
      target_port = 3000
    }
    load_balancer_ip = "${var.network_subnet}.${var.net_hosts.torrent_rpc}"
    selector = {
      "app" : "torrent"
    }
    type = "LoadBalancer"
  }
}

resource "kubernetes_persistent_volume" "torrent_shared_nfs" {
  metadata {
    name = "torrent-pv"
    labels = {
      name  = "type"
      value = "local"
    }
  }
  spec {
    capacity = {
      storage = "8Ti"
    }
    storage_class_name = kubernetes_storage_class.torrent_nfs.metadata.0.name
    access_modes       = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = var.nfs_storage.torrent
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "torrent_shared_nfs_claim" {
  metadata {
    name      = "torrent-pvc"
    namespace = kubernetes_namespace.torrent_ns.metadata.0.name
  }
  spec {
    storage_class_name = kubernetes_storage_class.torrent_nfs.metadata.0.name
    access_modes       = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "8Ti"
      }
    }
    volume_name = kubernetes_persistent_volume.torrent_shared_nfs.metadata.0.name
  }
}

## rTorrent deployment

resource "kubernetes_deployment" "flood-torrent" {
  depends_on = [kubernetes_persistent_volume_claim.torrent_shared_nfs_claim]
  metadata {
    name = "flood-torrent"
    labels = {
      app = "torrent"
    }
    namespace = kubernetes_namespace.torrent_ns.metadata.0.name
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "torrent"
      }
    }
    template {
      metadata {
        labels = {
          app = "torrent"
        }
      }

      spec {
        volume {
          name = "torrent-v-nfs"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.torrent_shared_nfs_claim.metadata.0.name
          }
        }
        container {
          name  = "flood-torrent"
          image = "ghcr.io/lukaszraczylo/flood:1.2292.7"
          env {
            name  = "FLOOD_DISABLE_AUTH"
            value = "true"
          }
          args = ["--rthost", "${var.network_subnet}.${var.net_hosts.torrent_rpc}",
            "--rtport", "5000", "-e", "HOME=/config", "--auth", "none", "-d", "/config/flood",
            "--allowedpath", "/config",
            "--allowedpath", "/data",
          "--rtorrent", "--rtconfig", "/data/rtorrent/.rtorrent.rc"]
          port {
            container_port = 3000
            protocol       = "TCP"
          }
          port {
            container_port = 5000
            protocol       = "TCP"
          }
          port {
            container_port = 23340
            protocol       = "TCP"
          }
          port {
            container_port = 23340
            protocol       = "UDP"
          }
          volume_mount {
            mount_path = "/data"
            name       = "torrent-v-nfs"
          }
          volume_mount {
            mount_path = "/mnt/storage/torrent/downloaded"
            sub_path   = "downloaded"
            name       = "torrent-v-nfs"
          }
          volume_mount {
            mount_path = "/config"
            sub_path   = "flood"
            name       = "torrent-v-nfs"
          }
        }
      }
    }
  }
}