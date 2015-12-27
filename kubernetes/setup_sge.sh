#!/bin/sh

WORKER_NUM=$1
TIMEOUT=240
SLEEP_INTERVAL=5
SGE_DIR=kubernetes/sge

echo "# Boot NFS servers"
kubectl create -f ${SGE_DIR}/nfshome-rc.yaml 
kubectl create -f ${SGE_DIR}/nfsopt-rc.yaml
kubectl create -f ${SGE_DIR}/nfshome-svc.yaml
kubectl create -f ${SGE_DIR}/nfsopt-svc.yaml
I=0
while [ $I -le $TIMEOUT ]; do
    if [ "`kubectl get pods -l app=nfshome 2>&1 | grep nfshome  | awk '{print $3}'`" = "Running" ]; then
        break
    fi
    echo "Wait NFS home server..."
    I=`expr $I + $SLEEP_INTERVAL`
    sleep $SLEEP_INTERVAL
done
kubectl get pods -l app=nfshome
if [ $I -gt $TIMEOUT ]; then
    echo "Timeout"
    exit 1
fi

I=0
while [ $I -le $TIMEOUT ]; do
    if [ "`kubectl get pods -l app=nfsopt 2>&1 | grep nfsopt | awk '{print $3}'`" = "Running" ]; then
        break
    fi
    echo "Wait NFS opt server..."
    I=`expr $I + $SLEEP_INTERVAL`
    sleep $SLEEP_INTERVAL
done
kubectl get pods -l app=nfsopt
if [ $I -gt $TIMEOUT ]; then
    echo "Timeout"
    exit 1
fi
echo ""


echo "# Boot SGE master"
kubectl create -f ${SGE_DIR}/sgemaster-pod.yaml
I=0
while [ $I -le $TIMEOUT ]; do
    if [ "`kubectl logs sgemaster | tail -1 | awk '{print $1}'`" = "Install" ]; then
        break
    fi
    echo "Wait SGE master..."
    I=`expr $I + $SLEEP_INTERVAL`
    sleep $SLEEP_INTERVAL
done
kubectl get pods -l app=sgemaster
if [ $I -gt $TIMEOUT ]; then
    echo "Timeout"
    exit 1
fi
echo ""

echo "# Boot ${WORKER_NUM:=1} SGE workers"
echo "" > ${SGE_DIR}/sgeworkers-pod.yaml
for i in $(seq 1 ${WORKER_NUM:=1}); do
    NAME=$(printf sgeworker%03d $i)
    sed -e "s/sgeworker001/${NAME}/g" ${SGE_DIR}/sgeworker-pod.yaml >> ${SGE_DIR}/sgeworkers-pod.yaml
done;

kubectl create -f ${SGE_DIR}/sgeworkers-pod.yaml
I=0
while [ $I -le $TIMEOUT ]; do
    if [ "`kubectl logs $(printf sgeworker%03d ${WORKER_NUM:=1}) | tail -1 | awk '{print $1}'`" = "Install" ]; then
        break
    fi
    echo "Wait SGE workers..."
    I=`expr $I + $SLEEP_INTERVAL`
    sleep $SLEEP_INTERVAL
done
kubectl get pods -l app=sgeworker
if [ $I -gt $TIMEOUT ]; then
    echo "Timeout"
    exit 1
fi
echo ""

echo "# SGE Usage:"
echo "  kubectl exec sgemaster -- sudo su sgeuser bash -c '. /etc/profile.d/sge.sh; echo "/bin/hostname" | qsub'"
echo "  kubectl exec sgemaster -- sudo su sgeuser bash -c 'cat /home/sgeuser/STDIN.o1'"