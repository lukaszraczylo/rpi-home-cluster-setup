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

resource "null_resource" "flannel_networking_patch" {
  depends_on = [ null_resource.flannel_networking ]
  provisioner = "local-exec" {
    when   = create
    command = << EOF
kubectl patch configmap kube-flannel-cfg -n kube-system -p '{
  "data": {
    "net-conf.json": "{\r\n\t\"Network\": \"10.244.0.0/16\",\r\n\t\"Backend\": { \r\n\t\t\"Type\": \"host-gw\"\n\t}\n}"
  }
}'"
EOF
  }

}