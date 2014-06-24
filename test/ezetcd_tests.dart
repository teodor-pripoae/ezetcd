import 'package:ezetcd/ezetcd.dart';
import 'package:scheduled_test/scheduled_test.dart';
import 'dart:async';



main() {


  /* 
   * TODO: Use an etcd docker container for testing.
   * NOTE: Setup and tear down are run as tests because of issues with setup and etcd.
   * The vm ends up hanging or race conditions are introduced with the directories.
   */
  test('should setup', _shouldSetup);
  test('should create key', _shouldCreateKey);
  test('should update key', _shouldUpdateKey);
  test('should delete key', _shouldDeleteKey);
  test('should watch directory', _shouldWatchDirectory);
  test('should teardown', _shouldTeardown);

}

_shouldSetup() {
  var client = new EtcdClient();

  schedule(() {
    return client.deleteNode('/ezetcd_tests', recursive: true);
  });

  schedule(() {
    return client.setNode('/ezetcd_tests', directory: true);
  });
}

_shouldTeardown() {
  var client = new EtcdClient();

  schedule(() {
    return client.deleteNode('/ezetcd_tests', recursive: true);
  });

}

_shouldCreateKey() {
  var client = new EtcdClient();

  var createResultReady = schedule(() {
    return client.setNode('/ezetcd_tests/key', value: 'value');
  });

  schedule(() {
    createResultReady.then((event) {
      expect(event.newValue.key, equals('/ezetcd_tests/key'));
      expect(event.type, equals(NodeEventType.CREATED));
      expect(event.newValue.value, equals('value'));
    });
  });


  var getResultReady = schedule(() {
    return client.getNode('/ezetcd_tests/key');

  });

  schedule(() {
    getResultReady.then((node) {
      expect(node.key, equals('/ezetcd_tests/key'));
      expect(node.value, equals('value'));
      client.close();
    });
  });

}

_shouldUpdateKey() {
  var client = new EtcdClient();

  var createResultReady = schedule(() {
    return client.setNode('/ezetcd_tests/key', value: 'value');
  });

  schedule(() {
    createResultReady.then((event) {
      expect(event.newValue.key, equals('/ezetcd_tests/key'));
    });
  });


  var updateResultReady = schedule(() {

    return client.setNode('/ezetcd_tests/key', value: 'value2');

  });

  schedule(() {
    updateResultReady.then((event) {
      expect(event.newValue.key, equals('/ezetcd_tests/key'));
      expect(event.type, equals(NodeEventType.MODIFIED));
      expect(event.newValue.value, equals('value2'));
      client.close();
    });
  });
}

_shouldDeleteKey() {

  var client = new EtcdClient();

  var createResultReady = schedule(() {

    return client.setNode('/ezetcd_tests/key', value: 'value');
  });


  var removeResultReady = schedule(() {
    return client.deleteNode('/ezetcd_tests/key');

  });

  schedule(() {
    removeResultReady.then((event) {
      expect(event.oldValue.key, equals('/ezetcd_tests/key'));
      expect(event.oldValue.value, equals('value'));
      expect(event.type, equals(NodeEventType.DELETED));
      client.close();
    });
  });
}

_shouldWatchDirectory() {
  var client = new EtcdClient();

  var events = [];

  schedule(() {
    return client.setNode('/ezetcd_tests/watched', directory: true);
  });

  var eventsReady = new Completer();

  schedule(() {
    var sub;
    sub = client.watch('/ezetcd_tests/watched', recursive: true).listen((e) {
      events.add(e);
      if (events.length == 1) {
        sub.cancel();
        eventsReady.complete(events);
      }
    }, onError: (e, ss) {
      eventsReady.completeError(e, ss);
    });
    return new Future.delayed(new Duration(seconds: 1));
  });

  schedule(() {
    return client.setNode('/ezetcd_tests/notwatched');
  });

  schedule(() {
    return client.setNode('/ezetcd_tests/watched/a', value: 'value');
  });


  schedule(() {
    var completer = new Completer();
    eventsReady.future.then((e) {
      expect(events.length, equals(1));
      expect(events[0].type, equals(NodeEventType.CREATED));
      expect(events[0].newValue.key, equals('/ezetcd_tests/watched/a'));
      completer.complete();
      client.close();
    }).catchError((e, ss) {
      completer.completeError(e, ss);
    });
    return completer.future;
  });


}
