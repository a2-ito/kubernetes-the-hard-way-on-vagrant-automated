echo "################################################################################"
echo "# Start running 07-networking-calico.sh"
echo "################################################################################"

echo "## Configure SELinux"
for instance in ${instances[@]};
do
  ssh ${instance} "\
  sudo sysctl net.ipv4.conf.all.forwarding=1
  "
done

POD_CIDR=10.200.0.0\\\/16
cp -p /vagrant/manifests/calico.yaml .
sed -i s/POD_CIDR/${POD_CIDR}/g calico.yaml

kubectl apply -f calico.yaml
