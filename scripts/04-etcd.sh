#!/bin/bash

echo "################################################################################"
echo "# Start running 04-etcd.sh"
echo "################################################################################"
instances=($@)

for instance in "${instances[@]}";
do
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
      service-account-key.pem service-account.pem ${instance}:/tmp
done

echo "## Install etcd binaries"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo mkdir -p /etc/etcd /var/lib/etcd
    sudo cp /tmp/ca.pem /tmp/kubernetes-key.pem /tmp/kubernetes.pem /etc/etcd/
    cp -p /vagrant/binaries/etcd-v3.4.0-linux-amd64.tar.gz .
    tar xzf etcd-v3.4.0-linux-amd64.tar.gz 2> /dev/null
    sudo mv etcd-v3.4.0-linux-amd64/etcd* /usr/local/bin/
    "
done

echo "## Configure the etcd Server"
for instance in "${instances[@]}"; do
  export INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  if [ -n "${_initial_cluster}" ]; then
    _initial_cluster=${_initial_cluster},${instance}=https:\\\/\\\/${INTERNAL_IP}:2380
  else
    _initial_cluster=${instance}=https:\\\/\\\/${INTERNAL_IP}:2380
  fi
done

for instance in "${instances[@]}"; do
cat > etcd.service <<"EOF"
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name ETCD_NAME \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --initial-advertise-peer-urls https://INTERNAL_IP:2380 \
  --listen-peer-urls https://INTERNAL_IP:2380 \
  --listen-client-urls https://INTERNAL_IP:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://INTERNAL_IP:2379 \
  --initial-cluster-token etcd-cluster \
  --initial-cluster INITIAL_CLUSTER \
  --initial-cluster-state new \
	--data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  #export INTERNAL_IP=${instance}
  export INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  export ETCD_NAME=${instance}
  sed -i s/INTERNAL_IP/${INTERNAL_IP}/g etcd.service
  sed -i s/ETCD_NAME/${ETCD_NAME}/g etcd.service
  export INITIAL_CLUSTER=${_initial_cluster}
  sed -i s/INITIAL_CLUSTER/${INITIAL_CLUSTER}/g etcd.service
  #sed -e 's/INITIAL_CLUSTER/http:\//g' etcd.service

  scp etcd.service ${instance}:/tmp
  ssh ${instance} "sudo mv /tmp/etcd.service /etc/systemd/system/"
done

echo "## Start etcd Service"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd &
  "
done

echo "## Start running 04-etcd.sh"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
  sudo ETCDCTL_API=3 /usr/local/bin/etcdctl member list \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/etcd/ca.pem \
    --cert=/etc/etcd/kubernetes.pem \
    --key=/etc/etcd/kubernetes-key.pem
  "
done

