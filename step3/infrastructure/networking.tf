# Basic networking

module "networking_flannel" {
  source = "./modules/networking-flannel"
}

resource "kubernetes_namespace" "metallb_system" {
  metadata {
    name = "metallb-system"
    labels = {
      app = "metallb"
    }
  }
}

module "networking_metallb" {
  depends_on = [kubernetes_namespace.metallb_system]
  source     = "./modules/networking-metallb"
}

resource "random_string" "metallb_secret_string" {
  length  = 128
  special = false
}

resource "kubernetes_secret" "metallb_secret" {
  type = "generic"
  metadata {
    name      = "memberlist"
    namespace = "metallb-system"
  }
  data = {
    secretkey = base64encode(random_string.metallb_secret_string.result)
  }
}

resource "kubernetes_config_map" "metallb_cfg_map" {
  metadata {
    name      = "config"
    namespace = "metallb-system"
  }

  data = {
    config = <<CFGMAP
  address-pools:
  - name: default
    protocol: layer2
    addresses:
    - ${var.network_subnet}.200-${var.network_subnet}.250
    CFGMAP
  }
}
