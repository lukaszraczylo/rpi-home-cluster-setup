# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

resource "null_resource" "metrics_server" {

  provisioner "local-exec" {
    when    = create
    command = "kubectl apply -f ./static/metrics-server.yaml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f ./static/metrics-server.yaml"
  }
}