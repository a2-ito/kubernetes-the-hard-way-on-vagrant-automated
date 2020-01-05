#!/bin/bash

#################################################################################
# Environment values
#################################################################################
instances="node1 node2"
#instances="node1"

# 00
rm ./*.pem ./*.json ./*.csr

# 01-compute.sh
/vagrant/scripts/01-compute.sh ${instances}

# 02-certificate-authority.sh
/vagrant/scripts/02-certificate-authority.sh ${instances}

# 03-kubeconfig.sh
/vagrant/scripts/03-kubeconfig.sh ${instances}

# 04-etcd.sh
/vagrant/scripts/04-etcd.sh ${instances}

# 05-controller.sh
/vagrant/scripts/05-controller.sh ${instances}

# 06-worker.sh
/vagrant/scripts/06-worker.sh ${instances}

# 07-networking.sh
/vagrant/scripts/07-networking.sh ${instances}

# 08-dns.sh
/vagrant/scripts/08-dns.sh

# 09-smoke-test.sh
/vagrant/scripts/09-smoke-test.sh ${instances}

