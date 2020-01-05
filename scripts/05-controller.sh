#!/bin/bash

echo "################################################################################"
echo "# Start running 05-controller.sh"
echo "################################################################################"
instances=($@)

echo "## The Encryption Config File"
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
for instance in "${instances[@]}"; do
  scp encryption-config.yaml ${instance}:/tmp
done

for instance in "${instances[@]}"; do
  K8S_VER=v1.15.5
  K8S_ARCH=amd64
  #ssh ${instance} "\
  #wget -nv https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kube-apiserver
  #wget -nv https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kube-controller-manager
  #wget -nv https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kube-scheduler
  scp /vagrant/binaries/kube-apiserver \
      /vagrant/binaries/kube-controller-manager \
      /vagrant/binaries/kube-scheduler \
      /vagrant/binaries/kubectl ${instance}:~
done

echo "### Install the Kubernetes binariesa"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo mkdir -p /etc/kubernetes/config
    chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
    sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin
  "
done

for instance in "${instances[@]}";
do
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
      service-account-key.pem service-account.pem ${instance}:/tmp
done

echo "####################################################################"
echo "## Configure the Kubernetes API Server"
echo "####################################################################"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo mkdir -p /var/lib/kubernetes/
    sudo mv /tmp/ca.pem /tmp/ca-key.pem /tmp/kubernetes-key.pem /tmp/kubernetes.pem \
      /tmp/service-account-key.pem /tmp/service-account.pem \
      /tmp/encryption-config.yaml /var/lib/kubernetes
  "
done

echo "### Create the kube-apiserver.service systemd unit file"
for instance in "${instances[@]}"; do
  export INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  if [ -n "${_etcd_servers}" ]; then
    _etcd_servers=${_etcd_servers},https:\\\/\\\/${INTERNAL_IP}:2379
  else
    _etcd_servers=https:\\\/\\\/${INTERNAL_IP}:2379
  fi
done

for instance in "${instances[@]}"; do
  INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  sed -i s/INTERNAL_IP/${INTERNAL_IP}/g /vagrant/manifests/kube-apiserver.service
  sed -i s/ETCD_SERVERS/${_etcd_servers}/g /vagrant/manifests/kube-apiserver.service
  scp /vagrant/manifests/kube-apiserver.service ${instance}:/tmp
  ssh ${instance} "sudo mv /tmp/kube-apiserver.service /etc/systemd/system/"
  ssh ${instance} "cat /etc/systemd/system/kube-apiserver.service"
done

for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kube-apiserver
    sudo systemctl start kube-apiserver &
  "
done
#for instance in "${instances[@]}"; do
#  ssh ${instance} "\
#    sudo systemctl status kube-apiserver -l
#  "
#done

echo "## Configure the Kubernetes Controller Manager"
echo "### Create the kube-controller-manager.service systemd unit file"
for instance in "${instances[@]}"; do
  scp /vagrant/manifests/kube-controller-manager.service kube-controller-manager.kubeconfig ${instance}:/tmp
  ssh ${instance} "\
     sudo mv /tmp/kube-controller-manager.service /etc/systemd/system/
     sudo mv /tmp/kube-controller-manager.kubeconfig /var/lib/kubernetes/kube-controller-manager.kubeconfig
  "
done

for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kube-controller-manager
    sudo systemctl start kube-controller-manager &
  "
done

## Verification

for instance in "${instances[@]}"; do
  ssh ${instance} "\
    kubectl get componentstatuses
  "
done

echo "## Configure the Kubernetes Scheduler"
echo "### Create the kube-scheduler.service systemd unit file"

for instance in "${instances[@]}"; do
  scp /vagrant/manifests/kube-scheduler.yaml /vagrant/manifests/kube-scheduler.service kube-scheduler.kubeconfig ${instance}:/tmp
  ssh ${instance} "\
    sudo mv /tmp/kube-scheduler.service /etc/systemd/system/
    sudo mv /tmp/kube-scheduler.kubeconfig /var/lib/kubernetes/
    sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/config/
  "
done

echo "## Start the Controller Services"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kube-scheduler
    sudo systemctl start kube-scheduler
  "
done

echo "## Verification"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    kubectl get componentstatuses
  "
done

echo "## RBAC for Kubelet Authorization"
/vagrant/binaries/kubectl apply --kubeconfig /tmp/admin.kubeconfig -f /vagrant/manifests/rbac-apiserver.yaml
