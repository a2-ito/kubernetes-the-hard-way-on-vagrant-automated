#!/bin/bash

echo "################################################################################"
echo "# Start running 03-kubeconfig.sh"
echo "################################################################################"
instances=($@)

sudo cp -p /vagrant/binaries/kubectl .
chmod +x kubectl

echo "## Create kubeconfibg"
INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instances[0]} | tail -n1 | awk '{print $NF}'`
for servertype in "${instances[@]}"; do
  ./kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=./ca.pem \
    --embed-certs=true \
    --server=https://"${INTERNAL_IP}":6443 \
    --kubeconfig=${servertype}.kubeconfig

  ./kubectl config set-credentials system:node:${servertype} \
    --client-certificate=./${servertype}.pem \
    --client-key=./${servertype}-key.pem \
    --embed-certs=true \
    --kubeconfig=${servertype}.kubeconfig

  ./kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${servertype} \
    --kubeconfig=${servertype}.kubeconfig

  ./kubectl config use-context default --kubeconfig=${servertype}.kubeconfig
done 

echo "## The kube-proxy Kubernetes Configuration File"
INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instances[0]} | tail -n1 | awk '{print $NF}'`
./kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=https://"${INTERNAL_IP}":6443 \
  --kubeconfig=kube-proxy.kubeconfig

./kubectl config set-credentials system:kube-proxy \
  --client-certificate=./kube-proxy.pem \
  --client-key=./kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

./kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

./kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

echo "## The kube-proxy Kubernetes Configuration File"
./kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

./kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=./kube-controller-manager.pem \
  --client-key=./kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

./kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

./kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

echo "## The kube-scheduler Kubernetes Configuration File"
./kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

./kubectl config set-credentials system:kube-scheduler \
  --client-certificate=./kube-scheduler.pem \
  --client-key=./kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

./kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

./kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

echo "## The admin Kubernetes Configuration File"
./kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=./ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

./kubectl config set-credentials admin \
  --client-certificate=./admin.pem \
  --client-key=./admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

./kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

./kubectl config use-context default --kubeconfig=admin.kubeconfig

for instance in "${instances[@]}";
do
  echo ${instance}
  scp ${instance}.kubeconfig kube-proxy.kubeconfig kube-controller-manager.kubeconfig \
		kube-scheduler.kubeconfig admin.kubeconfig ${instance}:/tmp
done
