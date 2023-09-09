#!/bin/bash

echo ".........----------------#################._.-.-INSTALL-.-._.#################----------------........."

# Limpieza de paqueteria
sudo apt-get autoremove -y      # Quitamos los paquetes que no se utilicen
sudo apt-get update             # Actualizamos los repositorios
sudo systemctl daemon-reload    # Recargamos las unidades de systemd 

# Añadimos repositorio de kubernetes
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Instalamos tools necesarias
KUBE_VERSION=1.20.0
sudo apt-get update
sudo apt-get install -y docker.io vim build-essential jq python3-pip kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00 kubernetes-cni=0.8.7-00 kubeadm=${KUBE_VERSION}-00 
pip3 install jc


cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2"
}
EOF
sudo mkdir -p /etc/systemd/system/docker.service.d

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker
sudo systemctl enable kubelet
sudo systemctl start kubelet


echo ".........----------------#################._.-.-KUBERNETES-.-._.#################----------------........."
sudo kubeadm reset -f
sudo kubeadm init --kubernetes-version=${KUBE_VERSION} --skip-token-print

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

sleep 60

echo "untaint controlplane node"
kubectl taint node $(kubectl get nodes -o=jsonpath='{.items[].metadata.name}') node.kubernetes.io/not-ready:NoSchedule-
kubectl taint node $(kubectl get nodes -o=jsonpath='{.items[].metadata.name}') node-role.kubernetes.io/master:NoSchedule-
kubectl get node -o wide


echo ".........----------------#################._.-.-Java and MAVEN-.-._.#################----------------........."
sudo apt install openjdk-11-jdk -y
java -version
sudo apt install -y maven
mvn -v


echo ".........----------------#################._.-.-JENKINS-.-._.#################----------------........."
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5BA31D57EF5975CA
sudo apt update
sudo apt install -y jenkins
sudo systemctl daemon-reload
sudo systemctl enable jenkins
sudo systemctl start jenkins
sudo usermod -a -G docker jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

echo ".........----------------#################._.-.-COMPLETED-.-._.#################----------------........."