
echo "################################################################################"
echo "# bootstrap with Google Cloud"
echo "################################################################################"
#_project=a2-itotest-`date +%Y%m%d`
#gcloud projects create ${_project} 
#gcloud config set project ${_project}
REGION=asia-northeast1
ZONE=asia-northeast1-a

gcloud config set compute/region ${REGION}
gcloud config set compute/zone ${ZONE}

echo "## Create IP"
#gcloud compute addresses create kubernetes-external-ip \
#  --region $(gcloud config get-value compute/region)
#gcloud compute addresses list --filter="name=('kubernetes-external-ip')"

echo "## Create VCN in australia-southeaset1"
gcloud compute networks create kubernetes-vpc-${ZONE} \
  --subnet-mode custom

echo "## Create subnets for Worker"
gcloud compute networks subnets create subnet-for-worker \
  --network kubernetes-vpc-${ZONE} \
  --region ${REGION} \
  --range 10.240.1.0/24

echo "## Create subnets for Master"
gcloud compute networks subnets create subnet-for-master \
  --network kubernetes-vpc-${ZONE} \
  --region ${REGION} \
  --range 10.241.1.0/24

echo "## Create Firewall Rules for Master and Workers"
gcloud compute firewall-rules create kubernetes-vpc-${ZONE}-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-vpc-${ZONE} \
  --source-ranges 10.240.0.0/16,10.241.0.0/16,10.242.1.0/24,10.200.0.0/16
gcloud compute firewall-rules create kubernetes-vpc-${ZONE}-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-vpc-${ZONE} \
  --source-ranges 0.0.0.0/0

echo "## Create Controllers VM"
for i in 1; do
  gcloud compute instances create master${i} \
    --async \
    --boot-disk-size 100GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --private-network-ip 10.241.1.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet subnet-for-master \
    --tags kubernetes-the-hard-way,controller \
    --preemptible
  gcloud compute instances add-metadata master${i} \
    --zone ${ZONE} \
    --metadata block-project-ssh-keys=FALSE
	_ip=`gcloud compute instances list --filter="name='master1'" --format="value(networkInterfaces[].accessConfigs[0].natIP)"`
  until ping -c1 ${_ip} >/dev/null 2>&1; do :; done
	sleep 5
  while true
	do
  	gcloud compute scp ~/.ssh/keys/id_rsa a2-ito@master${i}:~/.ssh/ --ssh-key-file=~/.ssh/keys/id_rsa
		if [ $? -ne 0 ]; then
			echo master${i} : ssh failed
			sleep 5
		else
			echo master${i} : ssh succeed!!
			break
		fi
	done
	gcloud compute scp --recurse ./scripts a2-ito@master${i}:~ --ssh-key-file=~/.ssh/keys/id_rsa
	gcloud compute scp ./bootstrap.sh a2-ito@master${i}:~ --ssh-key-file=~/.ssh/keys/id_rsa
	gcloud compute scp --recurse ./manifests a2-ito@master${i}:~ --ssh-key-file=~/.ssh/keys/id_rsa
done

#gcloud compute scp --recurse scripts  a2-ito@master1:~ --ssh-key-file=~/.ssh/keys/id_rsa
#gcloud compute scp ./bootstrap.sh   a2-ito@master1:~ --ssh-key-file=~/.ssh/keys/id_rsa

echo "## Create Workers VM"
for i in 1 2; do
  gcloud compute instances create worker${i} \
    --async \
    --boot-disk-size 100GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --metadata pod-cidr=10.200.1.0/24 \
    --private-network-ip 10.240.1.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet subnet-for-worker \
    --tags kubernetes-the-hard-way,worker \
    --preemptible
  gcloud compute instances add-metadata worker${i} \
    --zone ${ZONE} \
    --metadata block-project-ssh-keys=FALSE
  while true
	do
    gcloud compute scp ~/.ssh/keys/id_rsa a2-ito@worker${i}:~/.ssh/ --ssh-key-file=~/.ssh/keys/id_rsa
		if [ $? -ne 0 ]; then
			echo worker${i} : ssh failed
			sleep 5
		else
			echo worker${i} : ssh succeed!!
			break
		fi
	done
done

echo ssh -i ~/.ssh/keys/id_rsa -o 'StrictHostKeyChecking no' a2-ito@${_ip}
ssh -i ~/.ssh/keys/id_rsa -o 'StrictHostKeyChecking no' a2-ito@${_ip}

