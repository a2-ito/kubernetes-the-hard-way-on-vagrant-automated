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

if [[ ! -e ./binaries ]]; then
  mkdir -p ./binaries
else
	 rm -f ./binaries/*
fi

chmod 600 ~/.ssh/id_rsa

echo "## Install "
for instance in ${instances[@]}; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
  if [ -e /etc/redhat-release ]; then
    sudo yum update -y
		sudo yum install -y curl
		sudo yum install -y wget
		sudo yum install -y systemd
  else
    sudo apt update -y
    sudo apt install -y curl
		sudo apt install -y wget
    sudo apt install -y systemd
	  sudo apt install -y libseccomp-dev
  fi
	"	
done

echo "## Creaet SSH Keys"
if [[ ! -e ./binaries/cfssl ]]; then
  curl -s https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -o ./binaries/cfssl
  curl -s https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -o ./binaries/cfssljson
fi
sudo cp -p ./binaries/cfssl /bin/
sudo cp -p ./binaries/cfssljson /bin/
chmod +x /bin/cfssl /bin/cfssljson

echo "## Configure firewalld"
for instance in ${instances[@]}; do
  ssh -oStrictHostKeyChecking=no ${instance} "\
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
    #INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance2} | tail -n1 | awk '{print $NF}'`
    #INTERNAL_IP=`ssh ${instance2} hostname -i | awk '{print $NF}'`
    INTERNAL_IP=`ssh -oStrictHostKeyChecking=no ${instance2} "ip --oneline --family inet address show dev ${NIF}" |  cut -f1 -d'/' | awk '{print $NF}'`
		ssh -oStrictHostKeyChecking=no ${instance} "\
    sudo sh -c \"echo ${INTERNAL_IP} ${instance2} >> /etc/hosts\"
    "
  done
done

echo "## Configure SELinux"
for instance in ${instances[@]};
do
  ssh -oStrictHostKeyChecking=no ${instance} "\
  if [ -e /etc/redhat-release ]; then
    sudo sed -i s/^SELINUX=.*$/SELINUX=permissive/ /etc/selinux/config
    sudo setenforce Permissive
  fi
  "
done

echo "## mkdir kubernetes log dir"
for instance in ${instances[@]};
do
  ssh -oStrictHostKeyChecking=no ${instance} "\
  sudo mkdir /var/log/kubernetes/
	"
done


