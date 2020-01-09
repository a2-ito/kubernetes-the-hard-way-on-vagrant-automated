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
kubectl scale --replicas=$# deployment/nginx

echo "## Wait for Running"
kubectl get deployment
while true
do
  _status=`kubectl get pod | grep nginx | tail -n1 | awk '{print $3}'`
  _num_running=`kubectl get pod | grep nginx | grep Running | wc -l`
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
_num=`expr $# - 1`
for instance in ${instances[@]}; do
  for i in `seq 0 ${_num}`; do
    POD_IP=$(kubectl get pods -o jsonpath="{.items["${i}"].status.podIP}")
    echo pod on ${instance}" => "${POD_IP}
    kubectl run --image=giantswarm/tiny-tools \
      --rm --restart=Never -i testpod \
      --overrides='{"apiVersion": "v1", "spec": {"nodeSelector": {"kubernetes.io/hostname": "'${instance}'"}}}' \
      -- sh -c "curl -s --head http://${POD_IP}"
    echo;
    sleep 5
  done
done
