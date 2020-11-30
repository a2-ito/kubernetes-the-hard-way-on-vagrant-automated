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

echo "## Install libseccomp"
for instance in ${instances[@]}; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    if [ -e /etc/redhat-release ]; then
      sudo yum install -y libseccomp-dev
    else
      sudo apt install -y libseccomp-dev
    fi
  "
done

echo "## Copy Kubeconfigs"
for instance in "${instances[@]}"; do
  scp kube-proxy.kubeconfig ${instance}.kubeconfig ${instance}:/tmp
done


for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
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
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo swapoff -a
  "
done
#sudo swapon --show
#sed -i -e '/swap/d' /etc/fstab

echo "## Download Worker binaries"
if [[ ! -e ./binaries/kubelet ]]; then
  echo "#### Downloading kube-proxy/kubelet"
  wget -q --timestamping -P ./binaries/ \
    "https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kube-proxy" \
    "https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/$K8S_ARCH/kubelet" 
fi

if [[ ! -e ./binaries/cni-plugins-linux-amd64-${CNI_VER}.tgz ]]; then
  echo "#### Downloading cni-plugins"
  wget -q --timestamping -P ./binaries/ \
    "https://github.com/containernetworking/plugins/releases/download/${CNI_VER}/cni-plugins-linux-amd64-${CNI_VER}.tgz"
fi

if [[ ! -e ./binaries/crictl-${CRI_VER}-linux-amd64.tar.gz ]]; then
  echo "#### Downloading crictl"
  wget -q --timestamping -P ./binaries/ \
    "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_VER}/crictl-${CRI_VER}-linux-amd64.tar.gz"
fi

if [[ ! -e ./binaries/runc.amd64 ]]; then
  echo "#### Downloading runc/cotainerd"
  wget -q --timestamping -P ./binaries/ \
    "https://github.com/opencontainers/runc/releases/download/${RUNC_VER}/runc.amd64" \
    "https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}.linux-amd64.tar.gz"
fi
#		"https://github.com/containerd/containerd/releases/download/v1.3.6/containerd-1.3.6-linux-amd64.tar.gz"

echo "## Install Worker Binaries"
for instance in "${instances[@]}"; do
  scp ./binaries/cni-plugins-linux-amd64-v0.8.6.tgz \
      ./binaries/containerd-${CONTAINERD_VER}.linux-amd64.tar.gz \
      ./binaries/crictl-${CRI_VER}-linux-amd64.tar.gz \
      ./binaries/runc.amd64 \
      ./binaries/kubectl \
      ./binaries/kubelet \
      ./binaries/kube-proxy \
      ${instance}:/tmp
done

echo "## Create the installation directories"
for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
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
  ssh -oStrictHostKeyChecking=no ${instance} "\
    mkdir -p containerd
    tar -xvf /tmp/crictl-v1.18.0-linux-amd64.tar.gz
    tar -xvf /tmp/containerd-${CONTAINERD_VER}.linux-amd64.tar.gz -C containerd
    sudo tar -xvf /tmp/cni-plugins-linux-amd64-v0.8.6.tgz -C /opt/cni/bin/
    sudo mv /tmp/runc.amd64 /tmp/runc
    chmod +x crictl /tmp/kubectl /tmp/kube-proxy /tmp/kubelet /tmp/runc 
    sudo mv crictl /tmp/kubectl /tmp/kube-proxy /tmp/kubelet /tmp/runc /usr/local/bin/
    sudo mv containerd/bin/* /bin/
  "
done

echo "## Configure containerd"
for instance in "${instances[@]}"; do
  scp ./manifests/config.toml ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
  sudo mkdir -p /etc/containerd/
  sudo mv /tmp/config.toml /etc/containerd/
  "
done

for instance in "${instances[@]}";
do
  scp ./manifests/containerd.service ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
  sudo mv /tmp/containerd.service /etc/systemd/system/
  "
done

echo "# Start the Worker Services - containerd"
for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable containerd
    sudo systemctl start containerd
  "
done



echo "## Configure the Kubelet"
for instance in "${instances[@]}"; do
  scp ca.pem ${instance}.pem ${instance}-key.pem ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
  sudo mv /tmp/${instance}-key.pem /tmp/${instance}.pem /var/lib/kubelet/
  sudo mv /tmp/ca.pem /var/lib/kubernetes/
  "
done

echo "### Create the kubelet-config.yaml configurations file"
for instance in "${instances[@]}"; do
  _insnum=`echo ${instance} | rev | cut -c 1`
  POD_CIDR=10.200.${_insnum}.0\\\/24
	cp -p ./manifests/kubelet-config.yaml .
  sed -i s/POD_CIDR/${POD_CIDR}/g kubelet-config.yaml
  sed -i s/INSTANCE/${instance}/g kubelet-config.yaml
  scp kubelet-config.yaml ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo mv /tmp/kubelet-config.yaml /var/lib/kubelet/
  "
done

echo "### Create the kubelet.service systemd unit filea"
for instance in "${instances[@]}"; do
	cp -p ./manifests/kubelet.service .
  #INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  #INTERNAL_IP=`ssh ${instance} hostname -i | awk '{print $NF}'`
  INTERNAL_IP=`ssh -oStrictHostKeyChecking=no ${instance} "ip --oneline --family inet address show dev ${NIF}" |  cut -f1 -d'/' | awk '{print $NF}'`
 	sed -i s/INTERNAL_IP/${INTERNAL_IP}/g kubelet.service
	scp kubelet.service ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo mv /tmp/kubelet.service /etc/systemd/system/
    sudo mv /tmp/${instance}.kubeconfig /var/lib/kubelet/kubeconfig
  "
done

echo "# Start the Worker Services - kubelet"
for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kubelet
    sudo systemctl start kubelet
  "
done

for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo systemctl status kubelet
  "
done

echo "######################################################################"
echo "# Configure the Kubernetes Proxy"
echo "######################################################################"

for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo mv /tmp/kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  "
done

for instance in "${instances[@]}"; do
  scp ./manifests/kube-proxy-config.yaml ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo mv /tmp/kube-proxy-config.yaml /var/lib/kube-proxy
  "
done

echo "## Create the kube-proxy.service systemd unit file"
for instance in "${instances[@]}"; do
  scp ./manifests/kube-proxy.service ${instance}:/tmp
	ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo mv /tmp/kube-proxy.service /etc/systemd/system/
  "
done

echo "## Start the Worker Services - kube-proxy"
for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo systemctl daemon-reload
    sudo systemctl enable kube-proxy
    sudo systemctl start kube-proxy
  "
done

for instance in "${instances[@]}"; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo systemctl status kube-proxy
  "
done

echo "## Verification"
kubectl get nodes --kubeconfig /tmp/admin.kubeconfig

