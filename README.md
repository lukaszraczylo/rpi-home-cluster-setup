# Raspberry Pi kubernetes cluster on Alpine linux setup

This repository is supposed to help if I'd EVER AGAIN destroy the whole cluster by accident.
Code is a result of 6 hours coding marathon, but will be improved and patched in future.

## Usage

### Memory card preparations [step1]

To prepare memory cards check the **step1** directory.
If your Pi memory card is present under /dev/disk5 - you don't need to change anything, otherwise change it to the device of your choice.

```bash
PI_CARD="/dev/disk5"
```

Run the following script which will:
* Format memory card
* Split it into two partitions (1G + remaining)
* Copy basic Alpine system onto 1G partition
* Add an overlay allowing ethernet interface get up and SSH root access without the password

```bash
001-prepare-card.sh
```

### Cluster preparations [step2]

#### Before

* Modify pi-hosts.txt file and adjust it to your setup.
* Modify address class in step2/static/k8s-metallb-dashboard-config.yaml to suit your network

Add following to your ~/.ssh/config file

```bash
Host pi?
  User root
  Hostname %h.local
```

#### Prepare your nodes for Ansible

```bash
001-prepare-ansible.sh
```

#### Run the playbook

```bash
ansible-playbook rpi.yaml -f 10
```

### K8S definitions [step3]

Use makefile from step3 to apply / destroy resources

#### Required environment variables:

```bash
TRAEFIK_API_KEY // Traefik API key
GH_USER // GitHub user
GH_PAT // GitHub Personal Access Token
```

## Outcome

* Raspberry Pi cluster running Alpine linux as a base
* MetalLB for load balancing in your LAN
* Kubernetes dashboard installed and exposed via MetalLB
* Traefik managing the.. traffic