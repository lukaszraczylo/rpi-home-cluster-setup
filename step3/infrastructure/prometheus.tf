# resource "null_resource" "prometheus_pv" {

#   provisioner "local-exec" {
#     when    = create
#     command = "kubectl apply -f static/prometheus-pv.yaml"
#   }

#   provisioner "local-exec" {
#     when    = destroy
#     command = "kubectl delete -f static/prometheus-pv.yaml"
#   }
# }

resource "helm_release" "prometheus" {
  # depends_on = [ null_resource.prometheus_pv ]
  name       = "prometheus"
  namespace  = "default"
  chart      = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  wait       = false
  # set {
  #   name = "kube-state-metrics.image.repository"
  #   value = "carlosedp/kube-state-metrics"
  # }

  # set {
  #   name = "kube-state-metrics.image.tag"
  #   value = "v1.9.6"
  # }
}

resource "null_resource" "prometheus_patch" {
  depends_on = [helm_release.prometheus]
  provisioner "local-exec" {
    when    = create
    command = <<EOF
kubectl patch ds prometheus-prometheus-node-exporter --type json -p '[{"op": "remove", "path" : "/spec/template/spec/containers/0/volumeMounts/2/mountPropagation"}]' || true
    EOF
  }
}

resource "kubernetes_ingress" "traefik_grafana_routing" {
  metadata {
    name = "traefik-k8s-grafana"
    annotations = {
      "kubernetes.io/ingress.class" : "traefik"
    }
    namespace = "default"
  }

  spec {
    rule {
      host = "grafana.local"
      http {
        path {
          path = "/"
          backend {
            service_name = "prometheus-grafana"
            service_port = 80
          }
        }
      }
    }
  }
}