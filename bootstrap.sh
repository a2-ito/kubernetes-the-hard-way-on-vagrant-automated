#!/bin/bash

#################################################################################
# Environment values
#################################################################################
instances="master1 worker1 worker2"

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

# 01-compute.sh
/vagrant/scripts/01-compute.sh ${instances}

# 02-certificate-authority.sh
/vagrant/scripts/02-certificate-authority.sh ${instances}

# 03-kubeconfig.sh
/vagrant/scripts/03-kubeconfig.sh ${instances}

# 04-etcd.sh
/vagrant/scripts/04-etcd.sh ${masters}

# 05-controller.sh
/vagrant/scripts/05-controller.sh ${masters}

# 06-worker.sh
/vagrant/scripts/06-worker.sh ${workers}

# 07-networking.sh
/vagrant/scripts/07-networking-loopback.sh ${workers}
#/vagrant/scripts/07-networking-flannel.sh ${workers}
#/vagrant/scripts/07-networking-calico.sh ${workers}

# 08-dns.sh
/vagrant/scripts/08-dns.sh

# 09-smoke-test.sh
/vagrant/scripts/09-smoke-test.sh ${workers}

