#!/bin/bash

echo "################################################################################"
echo "# Start running 02-certificate-authority.sh"
echo "################################################################################"
instances=($@)

echo "## Certificate Authority"

cat > ./ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ./ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ./ca-csr.json | cfssljson -bare ca

echo "## Create Certificates"
cat > ./template-csr.json <<EOF
{
  "CN": "1_CN",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "2_C",
      "L": "3_L",
      "O": "4_O",
      "OU": "5_OU",
      "ST": "6_ST"
    }
  ]
}
EOF

_instances=`echo "${instances[@]}" | sed -e 's/ /,/g'`

for instance in "${instances[@]}"; do
  INTERNAL_IP=`cat ~/.ssh/config | grep -n1 ${instance} | tail -n1 | awk '{print $NF}'`
  if [ -n "${_node_ips}" ]; then
    _node_ips=${_node_ips},${INTERNAL_IP}
  else
    _node_ips=${INTERNAL_IP}
  fi
done
echo node_ips $_node_ips

sbj=(
kubernetes';'kubernetes';'US';'Portland';'Kubernetes';'"Kubernetes The Hard Way"';'Oregon';'"10.32.0.1,127.0.0.1,${_node_ips}"
kube-controller-manager';'system:kube-controller-manager';'US';'Portland';'system:kube-controller-manager';'"Kubernetes The Hard Way"';'Oregon';'""
kube-scheduler';'system:kube-scheduler';'US';'Portland';'system:kube-scheduler';'"Kubernetes The Hard Way"';'Oregon';'""
admin';'admin';'US';'Portland';'system:masters';'"Kubernetes The Hard Way"';'Oregon';'""
service-account';'service-accounts';'US';'Portland';'Kubernetes';'"Kubernetes The Hard Way"';'Oregon';'""
kube-proxy';'system:kube-proxy';'US';'Portland';'system:node-proxier';'"Kubernetes The Hard Way"';'Oregon';'""
)

for array in "${sbj[@]}"
do
  servertype=`echo "${array}" | cut -d';' -f1`
  _1_CN=`echo "${array}" | cut -d';' -f2`
  _2_C=`echo "${array}" | cut -d';' -f3`
  _3_L=`echo "${array}" | cut -d';' -f4`
  _4_O=`echo "${array}" | cut -d';' -f5`
  _5_OU=`echo "${array}" | cut -d';' -f6`
  _6_ST=`echo "${array}" | cut -d';' -f7`
  _7_HN=`echo "${array}" | cut -d';' -f8`
  cat ./template-csr.json |\
  sed -e "s/1_CN/${_1_CN}/g" \
	-e "s/2_C/${_2_C}/g" \
	-e "s/3_L/${_3_L}/g" \
	-e "s/4_O/${_4_O}/g" \
	-e "s/5_OU/${_5_OU}/g" \
	-e "s/6_ST/${_6_ST}/g" > ./${servertype}-csr.json
  cfssl gencert \
    -ca=./ca.pem \
    -ca-key=./ca-key.pem \
    -config=./ca-config.json \
    -profile=kubernetes \
    -hostname="${_7_HN}" \
    ./${servertype}-csr.json | cfssljson -bare ${servertype}
done

for instance in "${instances[@]}"
do
  servertype=${instance}
  _1_CN=system:node:${instance}
  _2_C=US
  _3_L=Portland
  _4_O=system:nodes
  _5_OU="Kubernetes The Hard Way"
  _6_ST=Oregon
  _7_HN=${instance}
  cat ./template-csr.json |\
  sed -e "s/1_CN/${_1_CN}/g" \
	-e "s/2_C/${_2_C}/g" \
	-e "s/3_L/${_3_L}/g" \
	-e "s/4_O/${_4_O}/g" \
	-e "s/5_OU/${_5_OU}/g" \
	-e "s/6_ST/${_6_ST}/g" > ./${servertype}-csr.json
  cfssl gencert \
    -ca=./ca.pem \
    -ca-key=./ca-key.pem \
    -config=./ca-config.json \
    -profile=kubernetes \
    -hostname="${_7_HN}" \
    ./${servertype}-csr.json | cfssljson -bare ${servertype}
done

