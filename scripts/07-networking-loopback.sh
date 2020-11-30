echo "################################################################################"
echo "# 07-networking"
echo "################################################################################"
instances=($@)

usage()
{
  echo $0 hoge
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

echo "## Configure CNI Networking"
for instance in "${instances[@]}"; do
  _insnum=`echo ${instance} | rev | cut -c 1`
  POD_CIDR=10.200.${_insnum}.0\\\/24
	cp -p ./manifests/10-bridge.conf .
  #sed -i s/POD_CIDR/${POD_CIDR}/g bridge.conf
  #sed -i s/POD/${POD_CIDR}/g bridge.conf
  sed -i s/POD_CIDR/${POD_CIDR}/g 10-bridge.conf
  scp -oStrictHostKeyChecking=no 10-bridge.conf ./manifests/99-loopback.conf ${instance}:/tmp
  ssh -oStrictHostKeyChecking=no ${instance} "\
  sudo mv /tmp/10-bridge.conf /etc/cni/net.d/
  sudo mv /tmp/99-loopback.conf /etc/cni/net.d/
  "
done

for instance1 in "${instances[@]}";
do
  for instance2 in "${instances[@]}";
  do
    if [ ${instance1} != ${instance2} ]; then
      #INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance2} | tail -n1 | awk '{print $NF}'`
      #INTERNAL_IP=`ssh ${instance1} hostname -i | awk '{print $NF}'`
      INTERNAL_IP=`ssh -oStrictHostKeyChecking=no ${instance1} "ip --oneline --family inet address show dev ${NIF}" |  cut -f1 -d'/' | awk '{print $NF}'`
			_insnum=`echo ${instance2} | rev | cut -c 1`
      ssh -oStrictHostKeyChecking=no ${instance1} "\
        echo "route add -net 10.200.${_insnum}.0 netmask 255.255.255.0 gw ${INTERNAL_IP}"
        sudo sh -c \"route add -net 10.200.${_insnum}.0 netmask 255.255.255.0 gw ${INTERNAL_IP}\"
      "
    fi
  done
done
