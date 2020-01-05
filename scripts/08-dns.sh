echo "##########################################################################"
echo "# 08-dns"
echo "##########################################################################"

echo "# Deploy the coredns cluster add-on:"
kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml \
  --kubeconfig admin.kubeconfig
kubectl get pods --kubeconfig admin.kubeconfig \
  -l k8s-app=kube-dns -n kube-system

while true
do
  _status=`kubectl get pod -n kube-system | grep coredns | tail -n1 | awk '{print $3}'`
	if [ "${_status}" != "Running" ]; then
		echo current status : ${_status}
    sleep 10
	else
		echo current status : ${_status}
		break
  fi
done

echo "## Verify dns"
kubectl run --image=giantswarm/tiny-tools \
  --rm --restart=Never -i testpod \
  -- nslookup kubernetes

