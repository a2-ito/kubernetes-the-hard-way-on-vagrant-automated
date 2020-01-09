echo "################################################################################"
echo "# Start running 07-networking-flannel.sh"
echo "################################################################################"


echo "## Configure SELinux"
for instance in ${instances[@]};
do
  ssh ${instance} "\
  sudo sysctl net.ipv4.conf.all.forwarding=1
  echo 'net.ipv4.conf.all.forwarding = 1' >> /etc/sysctl.conf
  "
done

POD_CIDR=10.200.0.0\\\/16
cp -p /vagrant/manifests/kube-flannel.yml .
sed -i s/POD_CIDR/${POD_CIDR}/g kube-flannel.yml

kubectl apply -f kube-flannel.yml

