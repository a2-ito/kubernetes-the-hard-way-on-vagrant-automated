
echo "################################################################################"
echo "# bootstrap with Google Cloud"
echo "################################################################################"
gcloud config set compute/region australia-southeast1
gcloud config set compute/zone australia-southeast1-a

echo "## Create VCN in australia-southeaset1"
gcloud compute addresses create kubernetes-external-ip \
  --region $(gcloud config get-value compute/region)
gcloud compute addresses list --filter="name=('kubernetes-external-ip')"

echo "## Create VCN in australia-southeaset1"
gcloud compute networks create kubernetes-vpc-australia-southeast1-a-proxy \
  --subnet-mode custom
gcloud compute networks create kubernetes-vpc-australia-southeast1-a \
  --subnet-mode custom
gcloud compute networks create kubernetes-vpc-australia-southeast1-b \
  --subnet-mode custom
gcloud compute networks create kubernetes-vpc-australia-southeast1-c \
  --subnet-mode custom

echo "## Create subnets for proxya"
gcloud compute networks subnets create subnet-proxy \
  --network kubernetes-vpc-australia-southeast1-a-proxy \
  --region=australia-southeast1 \
  --range 10.242.1.0/24

echo "## Create subnets for worker"
gcloud compute networks subnets create subnet-worker-1 \
  --network kubernetes-vpc-australia-southeast1-a \
  --region=australia-southeast1 \
  --range 10.240.1.0/24
gcloud compute networks subnets create subnet-worker-2 \
  --network kubernetes-vpc-australia-southeast1-b \
  --region=australia-southeast1 \
  --range 10.240.2.0/24
gcloud compute networks subnets create subnet-worker-3 \
  --network kubernetes-vpc-australia-southeast1-c \
  --region=australia-southeast1 \
  --range 10.240.3.0/24

echo "## Create subnets for Master"
gcloud compute networks subnets create subnet-master-1 \
  --network kubernetes-vpc-australia-southeast1-a \
  --region=australia-southeast1 \
  --range 10.241.1.0/24
gcloud compute networks subnets create subnet-master-2 \
  --network kubernetes-vpc-australia-southeast1-b \
  --region=australia-southeast1 \
  --range 10.241.2.0/24
gcloud compute networks subnets create subnet-master-3 \
  --network kubernetes-vpc-australia-southeast1-c \
  --region=australia-southeast1 \
  --range 10.241.3.0/24

echo "## Create Firewall Rules for Proxy"
gcloud compute firewall-rules create kubernetes-vpc-australia-southeast1-a-allow-internal-proxy \
  --allow tcp,udp,icmp \
  --network kubernetes-vpc-australia-southeast1-a-proxy \
  --source-ranges 10.240.0.0/16,10.241.0.0/16,10.242.1.0/24,10.200.0.0/16
gcloud compute firewall-rules create kubernetes-vpc-australia-southeast1-a-allow-external-proxy \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-vpc-australia-southeast1-a-proxy \
  --source-ranges 0.0.0.0/0

gcloud compute firewall-rules create kubernetes-vpc-australia-southeast1-a-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-vpc-australia-southeast1-a \
  --source-ranges 10.240.0.0/16,10.241.0.0/16,10.242.1.0/24,10.200.0.0/16
gcloud compute firewall-rules create kubernetes-vpc-australia-southeast1-a-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network kubernetes-vpc-australia-southeast1-a \
  --source-ranges 0.0.0.0/0

echo "## Create Firewall Rules for Master and Workers"
gcloud compute firewall-rules create kubernetes-vpc-australia-southeast1-a-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-vpc-australia-southeast1-a \
  --source-ranges 10.240.0.0/16,10.241.0.0/16,10.242.1.0/24,10.200.0.0/16
gcloud compute firewall-rules create kubernetes-vpc-australia-southeast1-b-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-vpc-australia-southeast1-b \
  --source-ranges 10.240.0.0/16,10.241.0.0/16,10.242.1.0/24,10.200.0.0/16
gcloud compute firewall-rules create kubernetes-vpc-australia-southeast1-c-allow-internal \
  --allow tcp,udp,icmp \
  --network kubernetes-vpc-australia-southeast1-c \
  --source-ranges 10.240.0.0/16,10.241.0.0/16,10.242.1.0/24,10.200.0.0/16

echo "## Create Controllers VM"
for _num in 1 2 3; do
  gcloud compute instances create master-${_num} \
    --async \
    --boot-disk-size 100GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --private-network-ip 10.241.1.1${_num} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet subnet-master-1 \
    --tags kubernetes-the-hard-way,controller \
    --zone=australia-southeast1-a \
    --preemptible
  gcloud compute instances add-metadata master-${_num} \
    --zone australia-southeast1-a \
    --metadata block-project-ssh-keys=FALSE
done

echo "## Create Workers VM"
#for i in 1 2 3; do
#  gcloud compute instances create worker-${i} \
#    --async \
#    --boot-disk-size 100GB \
#    --can-ip-forward \
#    --image-family ubuntu-1804-lts \
#    --image-project ubuntu-os-cloud \
#    --machine-type n1-standard-1 \
#    --metadata pod-cidr=10.200.${i}.0/24 \
#    --private-network-ip 10.240.${i}.11 \
#    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
#    --subnet subnet-worker-${i} \
#    --tags kubernetes-the-hard-way,worker \
#    --network-interface=no-address \
#    --no-address \
#    --preemptible
#done

echo "## Configure SSH keys"
for i in 1 2 3; do
#  gcloud compute instances add-metadata worker-${i} \
#    --zone australia-southeast1-a \
#    --metadata block-project-ssh-keys=FALSE
  gcloud compute instances add-metadata master-${i} \
    --zone australia-southeast1-a \
    --metadata block-project-ssh-keys=FALSE
done

echo "ssh -i ~/.ssh/keys/id_rsa -o 'StrictHostKeyChecking no' akihiko@104.154.160.11"

