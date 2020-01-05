echo "################################################################################"
echo "# 09-smoke-test"
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

echo "## Create sample deployment"
kubectl create deployment nginx --image=nginx --kubeconfig admin.kubeconfig
kubectl scale --replicas=2 deployment/nginx

echo "## Wait for Running"
kubectl get deployment
while true
do
  _status=`kubectl get pod | grep nginx | tail -n1 | awk '{print $3}'`
  _num_running=`kubectl get pod | grep Running | wc -l`
	#if [ "${_status}" != "Running" ]; then
	if [ "${_num_running}" -ne $# ]; then
		#echo current status : ${_status}
		echo current num of running : ${_num_running}
    sleep 10
	else
		#echo current status : ${_status}
		echo current num of running : ${_num_running}
		break
  fi
done
kubectl get pods

echo "## Vefify connectivity"
POD0_IP=$(kubectl get pods -o jsonpath="{.items[0].status.podIP}")
POD1_IP=$(kubectl get pods -o jsonpath="{.items[1].status.podIP}")
for instance1 in ${instances[@]}; do
	for instance2 in ${instances[@]}; do
    ssh ${instance1} "\
		echo pod on ${instance2}\" => \"${POD0_IP}
  	kubectl run --image=giantswarm/tiny-tools \
      --rm --restart=Never -i testpod \
      --overrides='{ \"apiVersion\": \"v1\", \"spec\": { \"nodeSelector\": { \"kubernetes.io/hostname\": \"${instance2}\" } } }' \
      -- sh -c \"curl -s --head http://${POD0_IP}\"
		echo;
		sleep 5
		echo pod on ${instance2}\" => \"${POD1_IP}
  	kubectl run --image=giantswarm/tiny-tools \
      --rm --restart=Never -i testpod \
      --overrides='{ \"apiVersion\": \"v1\", \"spec\": { \"nodeSelector\": { \"kubernetes.io/hostname\": \"${instance2}\" } } }' \
      -- sh -c \"curl -s --head http://${POD1_IP}\"
		echo;
		sleep 5
		"
  done
done
