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
  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }
  set {
    name  = "grafana.plugins"
    value = "devopsprodigy-kubegraf-app"
  }
  # set {
  #   name  = "prometheus-node-exporter.image.tag"
  #   value = "v1.1.2"
  # }
  # set {
  #   name = "prometheus.prometheusSpec.image.tag"
  #   value = "v2.25.1"
  # }
  # set {
  #   name = "prometheus.alertManagerSpec.image.tag"
  #   value = "v2.25.1"
  # }
}

## SEE following for the dashboard configuration
### https://grafana.com/grafana/plugins/devopsprodigy-kubegraf-app/

resource "null_resource" "kubegraf_dashboard" {
  depends_on = [helm_release.prometheus]
  provisioner "local-exec" {
    when    = create
    command = <<EOF
kubectl create ns kubegraf
kubectl apply -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/serviceaccount.yaml
kubectl apply -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/clusterrole.yaml
kubectl apply -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/clusterrolebinding.yaml
kubectl apply -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/secret.yaml
    EOF
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
kubectl delete -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/serviceaccount.yaml
kubectl delete -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/clusterrole.yaml
kubectl delete -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/clusterrolebinding.yaml
kubectl delete -f https://raw.githubusercontent.com/devopsprodigy/kubegraf/master/kubernetes/secret.yaml
kubectl delete ns kubegraf
    EOF
  }
}

resource "null_resource" "prometheus_patch" {
  depends_on = [helm_release.prometheus]
  provisioner "local-exec" {
    command = <<EOF
kubectl patch ds prometheus-prometheus-node-exporter --type json -p '[{"op": "remove", "path" : "/spec/template/spec/containers/0/volumeMounts/2/mountPropagation"}]' || true
    EOF
  }
}

resource "null_resource" "prometheus_crd_on_destroy" {
  depends_on = [helm_release.prometheus]
  provisioner "local-exec" {
    when    = destroy
    command = <<EOF
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com
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