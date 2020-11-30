echo "################################################################################"
echo "# Start running 07-networking-calico.sh"
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

echo "## Configure Sysctl"
for instance in ${instances[@]};
do
  ssh ${instance} "\
  sudo sysctl net.ipv4.conf.all.forwarding=1
  sudo sh -c 'echo \"net.ipv4.conf.all.forwarding = 1\" >> /etc/sysctl.conf'
  "
done

POD_CIDR=10.200.0.0\\\/16
cp -p ./manifests/calico.yaml .
sed -i s/POD_CIDR/${POD_CIDR}/g calico.yaml

kubectl apply -f calico.yaml
