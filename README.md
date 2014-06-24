ezetcd
======

Dart client for etcd, a highly available key-value store.

This client is suitable for talking to a local etcd server such as might be typical in a containerized environment.  The local etcd instance
is responsible for dealing with the cluster.


```

var client = new EtcdClient();

client.setNode('/directory1', directory:true).then((NodeEvent ne){

  print('created $ne');

});

```


todos
=======

 * compareAndSet
 * compareAndDelete
 * tls?
 
