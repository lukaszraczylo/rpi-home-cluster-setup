resource "null_resource" "metallb_networking" {

  provisioner "local-exec" {
    when    = create
    command = "kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/manifests/metallb.yaml; kubectl get configmap kube-proxy -n kube-system -o yaml | sed -e \"s/strictARP: false/strictARP: true/\" | kubectl apply -f - -n kube-system"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/main/manifests/metallb.yaml"
  }
}