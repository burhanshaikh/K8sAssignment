Steps 1 to 5 can be executed using the script - install.sh

1) Allow IP Tables see bridged traffic:

        cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
        br_netfilter
        EOF

        cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
        net.bridge.bridge-nf-call-ip6tables = 1
        net.bridge.bridge-nf-call-iptables = 1
        EOF
        sudo sysctl --system

2) Ensure these ports are open on the Particular nodes:
    
        Master: 
            6443* :- Kubernetes API Server
            2379-2380 :- ETCD Server Client API
            10250 :- Kubelet API
            10251 :- kube-scheduler
            10253 :- kube-controller-manager

        Worker:
            10250 :- Kubelet API
            30000 - 32767 :- NodePort Services


3) Install a container runtime:

        Let's choose Docker and install it

        sudo apt-get update -y
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg-agent \
            software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
        sudo apt-get update -y
        sudo apt-get install -y docker-ce

        Configure the Docker daemon, in particular to use systemd for the management of the container’s cgroups:

        cat <<EOF | sudo tee /etc/docker/daemon.json
        {
        "exec-opts": ["native.cgroupdriver=systemd"],
        "log-driver": "json-file",
        "log-opts": {
            "max-size": "100m"
        },
        "storage-driver": "overlay2"
        }
        EOF

        sudo systemctl enable docker
        sudo systemctl daemon-reload
        sudo systemctl restart docker



4) Install Kubeadm, Kubelet and Kubectl 

        Note: There is no need to install Kubectl on the worker nodes but it is a good to have as a feature.

        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl

        sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg

        echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl

5) Install ipvs kernel modules and ipset

        sudo apt-get install ipvsadm -y
        sudo modprobe -- ip_vs_rr
        sudo modprobe -- ip_vs_wrr
        sudo modprobe -- ip_vs_sh
        sudo modprobe -- nf_conntrack

        sudo apt install ipset -y


6) Create a custom Kubeadm yaml
   
        sudo kubeadm config print init-defaults > kubeadm.yaml

        Add the following lines to the file:

            apiVersion: kubeproxy.config.k8s.io/v1alpha1
            kind: KubeProxyConfiguration
            kubeProxy:
            config:
            mode: ipvs

        Important: Update the advertiseAddress field with your instance's private IP
        Remember to pass the custom kubeadm config file while running:
        kubeadm init --config <path_to_configuration_file>


7) kubeadm init when used with custom config file is not using ipvs even after specifying
   
        Alternate Strategy:
        
        Run kubeadm init with default config file and then edit configmap of kubeproxy, delete pods and check the logs of the new kubeproxy pods and they should mention "Using ipvs proxier"


8) Enable auditing

        Create the file: /etc/kubernetes/audit-policy.yaml with the following content:

            # Log all requests at the Metadata level.
            apiVersion: audit.k8s.io/v1
            kind: Policy
            rules:
            - level: Metadata
    
        Edit the kube-apiserver yaml file. Refer https://medium.com/cooking-with-azure/cks-exam-prep-setting-up-audit-policy-in-kubeadm-3f1b76bf4bd7

9) Install Weave Net CNI
  
        kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

10) Install etcd client 
    
        sudo apt install etcd-client

11) Create a bash script to take the backup of etcd which in turns ensures that you have the backup 
    of the cluster.

        Describe the etcd pod in the kube-system namespace to get the options(endpoint, cert, cacert, key) value for the etcdctl command

        Verify that the backup has been taken by running:                                             sudo ETCDCTL_API=3 etcdctl --write-out=table snapshot status BACKUPNAME

12) Install nginx Ingress controller
    
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/baremetal/deploy.yaml


13) On restricting the number of pods in training namespace to 5 and on scaling the worker deployment 
    to 4 pods we observe the following:

        The worker deployment does not scale to 4 pods, instead remains at one pod only
       
        Replica Status: 4 desired | 1 updated | 1 total | 1 available | 3 unavailable
       
        Conditions:
        Type             Status  Reason
        ----             ------  ------
        Available        False   MinimumReplicasUnavailable
        ReplicaFailure   True    FailedCreate

        Status in Kubernetes in-memory YAML file:

        message: 'pods "workerdeployment-6b96f88d5-dbgrw" is forbidden: exceeded quota:
        ns-pod-quota, requested: pods=1, used: pods=5, limited: pods=5'
        reason: FailedCreate
        status: "True"
        type: ReplicaFailure


14) Create a network policy that allows only the server, worker and client pods to connect to the
    database. All other direct connections should not be allowed

        Refer file: dbtraffic.yaml

15) Installing metrics server
    
        wget kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

        Edit the component.yaml file and make the following changes:
        - In the metrics-server deployment, under spec.template.spec.containers.args add/edit the following two arguments: 
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP

        Otherwise it results in Readiness and Liveliness Probe failure and the container will not run.

16) Observe the resource consumption metrics of the nodes and pods(training namespace)
    
        kubectl top nodes
        kubectl top pods

 