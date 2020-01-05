echo "## Copy Kubeconfigs"

echo "################################################################################"
echo "# Start running 06-worker.sh"
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

for instance in "${instances[@]}"; do
  scp kube-proxy.kubeconfig ${instance}.kubeconfig ${instance}:/tmp
done


for instance in "${instances[@]}"; do
  ssh ${instance} "\
  if [ -e /etc/redhat-release ]; then
  	sudo yum -y -q update
  	sudo yum -y -q install socat conntrack ipset
	elif [ -e /etc/lsb-release ]; then
  	sudo apt -y -q update
  	sudo apt -y -q install socat conntrack ipset
  fi
	"
done

echo "## Disable Swap"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo swapoff -a
    sudo swapon --show
  "
done

echo "## Download and Install Worker Binaries"
for instance in "${instances[@]}"; do
  #ssh ${instance} "\
    #wget -nv https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.15.0/crictl-v1.15.0-linux-amd64.tar.gz 
    #wget -nv https://github.com/opencontainers/runc/releases/download/v1.0.0-rc8/runc.amd64 
    #wget -nv https://github.com/containernetworking/plugins/releases/download/v0.8.2/cni-plugins-linux-amd64-v0.8.2.tgz
    #wget -nv https://github.com/containerd/containerd/releases/download/v1.2.9/containerd-1.2.9.linux-amd64.tar.gz
    #wget -nv https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubectl
    #wget -nv https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kube-proxy
    #wget -nv https://storage.googleapis.com/kubernetes-release/release/v1.15.3/bin/linux/amd64/kubelet
  #"
	scp /vagrant/binaries/cni-plugins-linux-amd64-v0.8.2.tgz \
		/vagrant/binaries/containerd-1.2.9.linux-amd64.tar.gz \
    /vagrant/binaries/crictl-v1.15.0-linux-amd64.tar.gz \
		/vagrant/binaries/runc.amd64 \
    ${instance}:/tmp
  scp /vagrant/binaries/kubectl /vagrant/binaries/kube-proxy /vagrant/binaries/kubelet ${instance}:/tmp 
done

echo "## Create the installation directories"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo mkdir -p \
      /etc/cni/net.d \
      /opt/cni/bin \
      /var/lib/kubelet \
      /var/lib/kube-proxy \
      /var/lib/kubernetes \
      /var/run/kubernetes
    "
done

echo "## Install the worker binaries"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    mkdir -p containerd
    tar -xvf /tmp/crictl-v1.15.0-linux-amd64.tar.gz
    tar -xvf /tmp/containerd-1.2.9.linux-amd64.tar.gz -C containerd
    sudo tar -xvf /tmp/cni-plugins-linux-amd64-v0.8.2.tgz -C /opt/cni/bin/
    sudo mv /tmp/runc.amd64 /tmp/runc
    chmod +x crictl /tmp/kubectl /tmp/kube-proxy /tmp/kubelet /tmp/runc 
    sudo mv crictl /tmp/kubectl /tmp/kube-proxy /tmp/kubelet /tmp/runc /usr/local/bin/
    sudo mv containerd/bin/* /bin/
  "
done

echo "## Configure CNI Networking"
for instance in "${instances[@]}"; do
  POD_CIDR=10.200.${instance:4:1}.0\\\/24
	cp -p /vagrant/manifests/10-bridge.conf .
  #sed -i s/POD_CIDR/${POD_CIDR}/g bridge.conf
  #sed -i s/POD/${POD_CIDR}/g bridge.conf
  sed -i s/POD_CIDR/${POD_CIDR}/g 10-bridge.conf
  scp 10-bridge.conf /vagrant/manifests/99-loopback.conf ${instance}:/tmp
  ssh ${instance} "\
  sudo mv /tmp/10-bridge.conf /etc/cni/net.d/
  sudo mv /tmp/99-loopback.conf /etc/cni/net.d/
  "
done

echo "## Configure containerd"
for instance in "${instances[@]}"; do
  scp /vagrant/manifests/config.toml ${instance}:/tmp
  ssh ${instance} "\
  sudo mkdir -p /etc/containerd/
  sudo mv /tmp/config.toml /etc/containerd/
  "
done

for instance in "${instances[@]}";
do
  scp /vagrant/manifests/containerd.service ${instance}:/tmp
  ssh ${instance} "\
  sudo mv /tmp/containerd.service /etc/systemd/system/
  "
done

echo "# Start the Worker Services - containerd"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable containerd
    sudo systemctl start containerd
  "
done



echo "## Configure the Kubelet"
for instance in "${instances[@]}"; do
  scp ca.pem ${instance}.pem ${instance}-key.pem ${instance}:/tmp
  ssh ${instance} "\
  sudo mv /tmp/${instance}-key.pem /tmp/${instance}.pem /var/lib/kubelet/
  sudo mv ca.pem /var/lib/kubernetes/
  "
done

echo "### Create the kubelet-config.yaml configurations file"
for instance in "${instances[@]}"; do
POD_CIDR=10.200.${instance:4:1}.0/24
cat <<EOF | tee kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
#resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${instance}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${instance}-key.pem"
EOF
  scp kubelet-config.yaml ${instance}:/tmp
  ssh ${instance} "\
    sudo mv /tmp/kubelet-config.yaml /var/lib/kubelet/
  "
done

echo "### Create the kubelet.service systemd unit filea"
for instance in "${instances[@]}"; do
	cp -p /vagrant/manifests/kubelet.service .
  INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  sed -i s/INTERNAL_IP/${INTERNAL_IP}/g kubelet.service
	scp kubelet.service ${instance}:/tmp
  ssh ${instance} "\
    sudo mv /tmp/kubelet.service /etc/systemd/system/
    sudo mv /tmp/${instance}.kubeconfig /var/lib/kubelet/kubeconfig
  "
done

echo "# Start the Worker Services - kubelet"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kubelet
    sudo systemctl start kubelet
  "
done

for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl status kubelet
  "
done

echo "######################################################################"
echo "# Configure the Kubernetes Proxy"
echo "######################################################################"

for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo mv /tmp/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  "
done

for instance in "${instances[@]}"; do
  scp /vagrant/manifests/kube-proxy-config.yaml ${instance}:/tmp
  ssh ${instance} "\
    sudo mv /tmp/kube-proxy-config.yaml /var/lib/kube-proxy
  "
done

echo "## Create the kube-proxy.service systemd unit file"
for instance in "${instances[@]}"; do
  scp /vagrant/manifests/kube-proxy.service ${instance}:/tmp
	ssh ${instance} "\
    sudo mv /tmp/kube-proxy.service /etc/systemd/system/
  "
done

echo "## Start the Worker Services - kube-proxy"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kube-proxy
    sudo systemctl start kube-proxy
  "
done

for instance in "${instances[@]}"; do
  ssh ${instance} "\
    sudo systemctl status kube-proxy
  "
done

echo "## Verification"
for instance in "${instances[@]}"; do
  ssh ${instance} "\
    kubectl get nodes --kubeconfig /tmp/admin.kubeconfig
  "
done

