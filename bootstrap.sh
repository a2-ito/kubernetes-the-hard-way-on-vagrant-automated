#!/bin/bash

#################################################################################
# Environment values
#################################################################################
instances="master1 worker1 worker2"
export K8S_VER=v1.18.12
export K8S_ARCH=amd64
export NIF=eth1
export CNI_VER=v0.8.6
export CRI_VER=v1.18.0
export RUNC_VER=v1.0.0-rc91
export CONTAINERD_VER=1.2.9

if [ `ip a | grep ${NIF} | wc -l` -gt 0 ]; then
  export NIF=eth1
else
  export NIF=ens4
fi

# 00
rm ./*.pem ./*.json ./*.csr

_instances=(`echo ${instances}`)
for instance in "${_instances[@]}"; do
  if [[ ${instance} == *master* ]]; then
    masters=${masters}" "${instance}
	else
		workers=${workers}" "${instance}
	fi
done

alias ssh='ssh -oStrictHostKeyChecking=no '

# 01-compute.sh
./scripts/01-compute.sh ${instances}

# 02-certificate-authority.sh
./scripts/02-certificate-authority.sh ${instances}

# 03-kubeconfig.sh
./scripts/03-kubeconfig.sh ${instances}

# 04-etcd.sh
./scripts/04-etcd.sh ${masters}

# 05-controller.sh
./scripts/05-controller.sh ${masters}

# 06-worker.sh
./scripts/06-worker.sh ${workers}

# 07-networking.sh
./scripts/07-networking-loopback.sh ${workers}
#./scripts/07-networking-flannel.sh ${workers}
#./scripts/07-networking-calico.sh ${workers}

# 08-dns.sh
./scripts/08-dns.sh

# 09-smoke-test.sh
./scripts/09-smoke-test.sh ${workers}

