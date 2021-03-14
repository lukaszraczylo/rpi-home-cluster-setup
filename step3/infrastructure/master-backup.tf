resource "kubernetes_storage_class" "etc_backup_nfs" {
  metadata {
    name = "nfs-etc-backup"
  }
  storage_provisioner    = "local"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  volume_binding_mode    = "Immediate"
}


resource "kubernetes_persistent_volume" "etc_backup_shared_nfs" {
  metadata {
    name = "etc-backup-pv"
    labels = {
      name  = "type"
      value = "local"
    }
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    storage_class_name = kubernetes_storage_class.etc_backup_nfs.metadata.0.name
    access_modes       = ["ReadWriteMany"]
    persistent_volume_source {
      host_path {
        path = "${var.nfs_storage.general}/etcd-backup"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "etc_backup_shared_nfs_claim" {
  metadata {
    name      = "etc-backup-pvc"
    namespace = "kube-system"
  }
  spec {
    storage_class_name = kubernetes_storage_class.etc_backup_nfs.metadata.0.name
    access_modes       = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.etc_backup_shared_nfs.metadata.0.name
  }
}


resource "kubernetes_cron_job" "etcd_backup" {
  metadata {
    name      = "etcd-backup"
    namespace = "kube-system"
  }
  spec {
    concurrency_policy            = "Replace"
    schedule                      = "30 1 * * *"
    starting_deadline_seconds     = 10
    successful_jobs_history_limit = 2
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            host_network = true
            node_selector = {
              "node-role.kubernetes.io/master" = ""
            }
            volume {
              name = "backup-v-nfs"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.etc_backup_shared_nfs_claim.metadata.0.name
              }
            }
            volume {
              name = "etcd-volume"
              host_path {
                path = "/etc/kubernetes/pki/etcd"
              }
            }
            container {
              name  = "etcd-backup"
              image = var.images.etcd
              env {
                name  = "ETCDCTL_API"
                value = "3"
              }
              command = ["/bin/sh"]
              args    = ["-c", "etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt --key=/etc/kubernetes/pki/etcd/healthcheck-client.key snapshot save /backup/etcd-snapshot-$(date +%Y-%m-%d_%H:%M:%S_%Z).db"]
              volume_mount {
                mount_path = "/backup"
                name       = "backup-v-nfs"
              }
              volume_mount {
                mount_path = "/etc/kubernetes/pki/etcd"
                name       = "etcd-volume"
                read_only  = true
              }
            }
          }
        }
      }
    }
  }
}

### Recovery from Master Failure
# When the master fails, we create a new master and initialize it with the data from the backup. Before running kubeadm init on the new master, we need to restore the data from the backup.

# First, we restore the root certificate files /etc/kubernetes/pki/ca.crt and /etc/kubernetes/pki/ca.key. Expected permissions are 0644 for ca.crt and 0600 for ca.key.

# Second, we run etcdctl to restore the etcd backup. We don’t need to install etcdctl on the host system, as we can use the Docker image. Assuming the latest backup is stored in /mnt/etcd-snapshot-2018-05-24_21:54:03_UTC.db, we can restore it with the following commands:

# mkdir -p /var/lib/etcd
# docker run --rm \
#     -v '/mnt:/backup' \
#     -v '/var/lib/etcd:/var/lib/etcd' \
#     --env ETCDCTL_API=3 \
#     'k8s.gcr.io/etcd-amd64:3.1.12' \
#     /bin/sh -c "etcdctl snapshot restore '/backup/etcd-snapshot-2018-05-24_21:54:03_UTC.db' ; mv /default.etcd/member/ /var/lib/etcd/"
# The command above should create a directory /var/lib/etcd/member/ with permissions 0700.

# Finally, we can run kubeadm init to create the new master. However, we need an extra parameters to make it accept the existing etcd data:

# kubeadm init --ignore-preflight-errors=DirAvailable--var-lib-etcd
# Assuming the new master is reachable under the same IP or hostname as the old master, the nodes will reconnect and the cluster is up and running again.