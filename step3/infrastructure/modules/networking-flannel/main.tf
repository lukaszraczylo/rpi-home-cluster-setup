# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

resource "null_resource" "flannel_networking" {

  provisioner "local-exec" {
    when    = create
    command = "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"
  }
}