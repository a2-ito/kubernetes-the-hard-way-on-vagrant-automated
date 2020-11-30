#!/bin/bash

echo "################################################################################"
echo "# Start running 05-controller.sh"
echo "################################################################################"
instances=($@)

usage()
{
  echo "$0 [node1] [node2] ..."
}

if [ -z $1 ]; then
  usage
  exit
else
  expr $1 + 1 >/dev/null 2>&1
fi

if [ $# -lt 1 ]; then
  echo "must be more than 1"
  exit
fi

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
  
  if [[ ! -e ./binaries/kube-apiserver ]]; then
    wget -q --timestamping -P ./binaries/ \
      "https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kube-apiserver" \
      "https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kube-controller-manager" \
      "https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kube-scheduler"
  fi
  scp ./binaries/kube-apiserver \
      ./binaries/kube-controller-manager \
      ./binaries/kube-scheduler \
      ./binaries/kubectl ${instance}:~
done

echo "### Install the Kubernetes binariesa"
for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
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
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo mkdir -p /var/lib/kubernetes/
    sudo mv /tmp/ca.pem /tmp/ca-key.pem /tmp/kubernetes-key.pem /tmp/kubernetes.pem \
      /tmp/service-account-key.pem /tmp/service-account.pem \
      /tmp/encryption-config.yaml /var/lib/kubernetes
  "
done

echo "### Create the kube-apiserver.service systemd unit file"
for instance in "${instances[@]}"; do
  #export INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  #export INTERNAL_IP=`hostname -i | awk '{print $NF}'`
  INTERNAL_IP=`ssh -oStrictHostKeyChecking=no ${instance} "ip --oneline --family inet address show dev ${NIF}" |  cut -f1 -d'/' | awk '{print $NF}'`
	if [ -n "${_etcd_servers}" ]; then
    _etcd_servers=${_etcd_servers},https:\\\/\\\/${INTERNAL_IP}:2379
  else
    _etcd_servers=https:\\\/\\\/${INTERNAL_IP}:2379
  fi
done

for instance in "${instances[@]}"; do
	cp -p ./manifests/kube-apiserver.service .
  #INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  #INTERNAL_IP=`hostname -i | awk '{print $NF}'`
  INTERNAL_IP=`ssh -oStrictHostKeyChecking=no ${instance} "ip --oneline --family inet address show dev ${NIF}" |  cut -f1 -d'/' | awk '{print $NF}'`
	sed -i s/INTERNAL_IP/${INTERNAL_IP}/g kube-apiserver.service
  sed -i s/ETCD_SERVERS/${_etcd_servers}/g kube-apiserver.service
  scp kube-apiserver.service ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "sudo mv /tmp/kube-apiserver.service /etc/systemd/system/"
  ssh -oStrictHostKeyChecking=no ${instance} "cat /etc/systemd/system/kube-apiserver.service"
done

for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
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
  scp ./manifests/kube-controller-manager.service kube-controller-manager.kubeconfig ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
     sudo mv /tmp/kube-controller-manager.service /etc/systemd/system/
     sudo mv /tmp/kube-controller-manager.kubeconfig /var/lib/kubernetes/kube-controller-manager.kubeconfig
  "
done

for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kube-controller-manager
    sudo systemctl start kube-controller-manager &
  "
done

## Verification

for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    kubectl get componentstatuses
  "
done

echo "## Configure the Kubernetes Scheduler"
echo "### Create the kube-scheduler.service systemd unit file"

for instance in "${instances[@]}"; do
  scp ./manifests/kube-scheduler.yaml ./manifests/kube-scheduler.service kube-scheduler.kubeconfig ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo mv /tmp/kube-scheduler.service /etc/systemd/system/
    sudo mv /tmp/kube-scheduler.kubeconfig /var/lib/kubernetes/
    sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/config/
  "
done

echo "## Start the Controller Services"
for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kube-scheduler
    sudo systemctl start kube-scheduler
  "
done

echo "## Verification"
for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    kubectl get componentstatuses
  "
done

echo "## RBAC for Kubelet Authorization"
chmod 755 ./binaries/kubectl
sleep 10
./binaries/kubectl apply --kubeconfig /tmp/admin.kubeconfig -f ./manifests/rbac-apiserver.yaml
