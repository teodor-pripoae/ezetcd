ezetcd
======

Dart client for [etcd](https://github.com/coreos/etcd), a highly available key-value store.

This client is suitable for talking to a local etcd server such as might be typical in a containerized environment.  The local etcd instance
is responsible for dealing with the cluster.


Usage
======

A running [etcd](https://github.com/coreos/etcd) instance is required.


_Run etcd in a [Docker](https://www.docker.com) container_

```
docker run -p 4001:4001 -p 7001:7001 coreos/etcd -name etcd
```

_Connect to the server with ezetcd_

```

import 'package:ezetcd/ezetcd.dart';

main(){

  var client = new EtcdClient();

  client.setNode('/directory1', directory:true).then((NodeEvent ne){

    print('created $ne');

  });
}

```


todos
=======

 * write tests for remaining SetCondition's and DeleteConditions
 * clear code todo's
 * tls?
 * improve dartdoc documentation
 
