ETCDCTL_API=3 \
etcdctl --endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
--data-dir /etcdbackup/restore \
 snapshot restore /etcdbackup/etcd-snapshot  

 # Ensure that the --data-dir folder does not exist(here restore), it gets created when we run this command.