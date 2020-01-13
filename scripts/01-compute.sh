#!/bin/bash

echo "################################################################################"
echo "# Start running 01-compute.sh"
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

if [[ ! -e /vagrant/binaries ]]; then
  mkdir -p /vagrant/binaries
fi

chmod 600 ~/.ssh/id_rsa

echo "## Creaet SSH Keys"
for instance in ${instances[@]}; do
  if [[ ! -e /vagrant/binaries/cfssl ]]; then
    curl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o /vagrant/binaries/cfssl
    curl https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o /vagrant/binaries/cfssljson
  fi
  ssh ${instance} "\
    sudo cp -p /vagrant/binaries/cfssl /bin/
    sudo cp -p /vagrant/binaries/cfssljson /bin/
    chmod +x /bin/cfssl /bin/cfssljson
  "
done

echo "## Configure firewalld"
for instance in ${instances[@]}; do
  ssh ${instance} "\
  if [ -e /etc/redhat-release ]; then
		sudo systemctl stop firewalld
		sudo systemctl disable firewalld
  fi
	"	
done

echo "## Configure language"
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_COLLATE=C
export LC_CTYPE=en_US.UTF-8

echo "## Edit hosts"
for instance in ${instances[@]}; do
  for instance2 in ${instances[@]}; do
    INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance2} | tail -n1 | awk '{print $NF}'`
    ssh ${instance} "\
    sudo sh -c \"echo ${INTERNAL_IP} ${instance2} >> /etc/hosts\"
    "
  done
done

echo "## Configure SELinux"
for instance in ${instances[@]};
do
  ssh ${instance} "\
  if [ -e /etc/redhat-release ]; then
    sudo sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config
    sudo setenforce Permissive
  fi
  "
done

echo "## mkdir kubernetes log dir"
for instance in ${instances[@]};
do
  ssh ${instance} "\
  sudo mkdir /var/log/kubernetes/
	"
done


