echo "################################################################################"
echo "# Start running 07-networking-flannel.sh"
echo "################################################################################"

POD_CIDR=10.200.0.0\\\/16
cp -p /vagrant/manifests/kube-flannel.yml .
sed -i s/POD_CIDR/${POD_CIDR}/g kube-flannel.yml

kubectl apply -f kube-flannel.yml

