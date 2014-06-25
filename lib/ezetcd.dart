
// Copyright (c) 2014, the Name It Later ezetcd project authors.
// Please see the AUTHORS file for details. All rights reserved. Use of this 
// source code is governed by the BSD 3 Clause license, a copy of which can be
// found in the LICENSE file.

/** 
 *  Client for etcd, a highly available key-value store.
 *  TODO: Use path instead of key consistently.
 *  TODO: Validate arguments
 *  TODO: Revisit error codes (some may never be reported to clients)
 **/

library ezetcd;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:intl/intl.dart';

final Logger _LOGGER = new Logger('ezetcd');
final DateFormat _FORMAT = new DateFormat('yyyy-MM-ddThh:mm:ss.S');

/// Raw etcd error codes as listed in [error.go](https://github.com/coreos/etcd/blob/master/error/error.go)
const int _KEY_NOT_FOUND = 100;
const int _TEST_FAILED = 101;
const int _NOT_A_FILE = 102;
const int _NO_MORE_PEER = 103;
const int _NOT_A_DIR = 104;
const int _NODE_EXIST = 105;
const int _KEY_IS_PRESERVED = 106;
const int _ROOTR_ONLY = 107;
const int _DIR_NOT_EMPTY = 108;
const int _EXISTING_PEER_ADDR = 109;

const int _VALUE_REQUIRED = 200;
const int _PREV_VALUE_REQUIRED = 201;
const int _TTL_NAN = 202;
const int _INDEX_NAN = 203;
const int _VALUE_OR_TTL_REQUIRED = 204;
const int _TIMEOUT_NAN = 205;
const int _NAME_REQUIRED = 206;
const int _INDEX_OR_VALUE_REQUIRED = 207;
const int _INDEX_VALUE_MUTEX = 208;
const int _INVALID_FIELD = 209;

const int _RAFT_INTERNAL = 300;
const int _LEADER_ELECT = 301;

const int _WATCHER_CLEARED = 400;
const int _EVENT_INDEX_CLEARED = 401;
const int _STANDBY_INTERNAL = 402;
const int _INVALID_ACTIVE_SIZE = 403;
const int _INVALID_REMOVE_DELAY = 404;

const int _CLIENT_INTERNAL = 500;

/// Map of raw error codes to [ErrorCode]
const Map<int, ErrorCode> _errorCodeMap = const {
  _KEY_NOT_FOUND: ErrorCode.KEY_NOT_FOUND,
  _TEST_FAILED: ErrorCode.TEST_FAILED,
  _NOT_A_FILE: ErrorCode.NOT_A_FILE,
  _NO_MORE_PEER: ErrorCode.NO_MORE_PEERS,
  _NOT_A_DIR: ErrorCode.NOT_A_DIRECTORY,
  _NODE_EXIST: ErrorCode.NODE_EXISTS,
  _ROOTR_ONLY : ErrorCode.ROOT_IS_READ_ONLY,
  _KEY_IS_PRESERVED : ErrorCode.KEY_IS_PRESERVED,
  _DIR_NOT_EMPTY : ErrorCode.DIRECTORY_NOT_EMPTY,
  _EXISTING_PEER_ADDR : ErrorCode.EXISTING_PEER_ADDRESS,
  _VALUE_REQUIRED: ErrorCode.VALUE_REQUIRED,
  _TTL_NAN: ErrorCode.TTL_NAN,
  _INDEX_NAN : ErrorCode.INDEX_NAN,
  _VALUE_OR_TTL_REQUIRED : ErrorCode.VALUE_OR_TTL_REQUIRED,
  _TIMEOUT_NAN: ErrorCode.TIMEOUT_NAN,
  _NAME_REQUIRED: ErrorCode.NAME_REQUIRED,
  _INDEX_OR_VALUE_REQUIRED: ErrorCode.INDEX_OR_VALUE_REQUIRED,
  _INDEX_VALUE_MUTEX: ErrorCode.INDEX_VALUE_MUTEX,
  _INVALID_FIELD: ErrorCode.INVALID_FIELD,
  _RAFT_INTERNAL: ErrorCode.RAFT_INTERNAL,
  _LEADER_ELECT: ErrorCode.LEADER_ELECT,
  _WATCHER_CLEARED: ErrorCode.WATCHER_CLEARED,
  _EVENT_INDEX_CLEARED: ErrorCode.EVENT_INDEX_CLEARED,
  _STANDBY_INTERNAL: ErrorCode.STANDBY_INTERNAL,
  _INVALID_ACTIVE_SIZE: ErrorCode.INVALID_ACTIVE_SIZE,
  _INVALID_REMOVE_DELAY: ErrorCode.INVALID_REMOVE_DELAY,
  _CLIENT_INTERNAL: ErrorCode.CLIENT_INTERNAL_ERROR
};

ErrorCode _lookupErrorCode(int code) {
  if (_errorCodeMap.containsKey(code)) {
    return _errorCodeMap[code];
  }
  throw new ArgumentError('Unknown error code [$code]');
}

/**
 * Error codes returned by etcd. 
 * 
 * Error codes returned by etcd. See [error.go](https://github.com/coreos/etcd/blob/master/error/error.go).
 */
class ErrorCode {

  final String _toString;
  final int code;

  const ErrorCode._(this.code, this._toString);

  static const ErrorCode KEY_NOT_FOUND = const ErrorCode._(_KEY_NOT_FOUND, 'KEY_NOT_FOUND');
  static const ErrorCode TEST_FAILED = const ErrorCode._(_TEST_FAILED, 'TEST_FAILED');
  static const ErrorCode NOT_A_FILE = const ErrorCode._(_NOT_A_FILE, 'NOT_A_FILE');
  static const ErrorCode NO_MORE_PEERS = const ErrorCode._(_NO_MORE_PEER, 'NO_MORE_PEERS');
  static const ErrorCode NOT_A_DIRECTORY = const ErrorCode._(_NOT_A_DIR, 'NOT_A_DIRECTORY');
  static const ErrorCode NODE_EXISTS = const ErrorCode._(_NODE_EXIST, 'NODE_EXISTS');
  static const ErrorCode ROOT_IS_READ_ONLY = const ErrorCode._(_ROOTR_ONLY, 'ROOT_IS_READ_ONLY');
  static const ErrorCode KEY_IS_PRESERVED = const ErrorCode._(_KEY_IS_PRESERVED, 'KEY_IS_PRESERVED');
  static const ErrorCode DIRECTORY_NOT_EMPTY = const ErrorCode._(_DIR_NOT_EMPTY, 'DIRECTORY_NOT_EMPTY');
  static const ErrorCode EXISTING_PEER_ADDRESS = const ErrorCode._(_EXISTING_PEER_ADDR, 'EXISTING_PEER_ADDRESS');
  static const ErrorCode VALUE_REQUIRED = const ErrorCode._(_VALUE_REQUIRED, 'VALUE_REQUIRED');
  static const ErrorCode PREVIOUS_VALUE_REQUIRED = const ErrorCode._(_PREV_VALUE_REQUIRED, 'PREVIOUS_VALUE_REQUIRED');
  static const ErrorCode TTL_NAN = const ErrorCode._(_TTL_NAN, 'TTL_NAN');
  static const ErrorCode INDEX_NAN = const ErrorCode._(_INDEX_NAN, 'INDEX_NAN');
  static const ErrorCode VALUE_OR_TTL_REQUIRED = const ErrorCode._(_VALUE_OR_TTL_REQUIRED, 'VALUE_OR_TTL_REQUIRED');
  static const ErrorCode TIMEOUT_NAN = const ErrorCode._(_TIMEOUT_NAN, 'TIMEOUT_NAN');
  static const ErrorCode NAME_REQUIRED = const ErrorCode._(_NAME_REQUIRED, 'NAME_REQUIRED');
  static const ErrorCode INDEX_OR_VALUE_REQUIRED = const ErrorCode._(_NOT_A_FILE, 'NOT_A_FILE');
  static const ErrorCode INDEX_VALUE_MUTEX = const ErrorCode._(_INDEX_VALUE_MUTEX, 'INDEX_VALUE_MUTEX');
  static const ErrorCode INVALID_FIELD = const ErrorCode._(_INVALID_FIELD, 'INVALID_FIELD');
  static const ErrorCode RAFT_INTERNAL = const ErrorCode._(_RAFT_INTERNAL, 'RAFT_INTERNAL');
  static const ErrorCode LEADER_ELECT = const ErrorCode._(_LEADER_ELECT, 'LEADER_ELECT');
  static const ErrorCode WATCHER_CLEARED = const ErrorCode._(_WATCHER_CLEARED, 'WATCHER_CLEARED');
  static const ErrorCode EVENT_INDEX_CLEARED = const ErrorCode._(_EVENT_INDEX_CLEARED, 'EVENT_INDEX_CLEARED');
  static const ErrorCode STANDBY_INTERNAL = const ErrorCode._(_STANDBY_INTERNAL, 'STANDBY_INTERNAL');
  static const ErrorCode INVALID_ACTIVE_SIZE = const ErrorCode._(_INVALID_ACTIVE_SIZE, 'INVALID_ACTIVE_SIZE');
  static const ErrorCode INVALID_REMOVE_DELAY = const ErrorCode._(_INVALID_REMOVE_DELAY, 'INVALID_REMOVE_DELAY');
  static const ErrorCode CLIENT_INTERNAL_ERROR = const ErrorCode._(_CLIENT_INTERNAL, 'CLIENT_INTERNAL_ERROR');
  
  toString() {
    return _toString;
  }

}

/**
 * Type of event related to a [Node].
 */
class NodeEventType {

  final String _toString;

  const NodeEventType._(this._toString);

  static const NodeEventType CREATED = const NodeEventType._('CREATED');
  static const NodeEventType MODIFIED = const NodeEventType._('MODIFIED');
  static const NodeEventType DELETED = const NodeEventType._('DELETED');

  toString() {
    return _toString;
  }

}

/**
 * An event that occurred related to a specific node.
 */
class NodeEvent {

  /**
   * The type of the event.
   */
  final NodeEventType type;
  
  /**
   * The new node value.
   */
  final Node newValue;
  
  /**
   * The old node value.
   */
  final Node oldValue;

  NodeEvent(this.type, {Node newValue, Node oldValue})
      : this.oldValue = oldValue,
        this.newValue = newValue;


  toString() {
    return '"type":$type, "oldValue":${oldValue}, "newValue":${newValue}';
  }

}

/**
 * A node in an etcd store.
 */
class Node {
  
  final String key;
  final int createdIndex;
  final int modifiedIndex;
  final DateTime expiration;
  final Duration ttl;
  final bool isDirectory;
  final String value;
  final List<Node> nodes;

  Node(this.key, this.createdIndex, this.modifiedIndex, {DateTime expiration, Duration ttl, String value, bool isDirectory: false, List<Node> nodes})
      : this.expiration = expiration,
        this.ttl = ttl,
        this.isDirectory = isDirectory,
        this.value = value,
        this.nodes = nodes;

  toString() {
    return '"key" : $key, "createdIndex": $createdIndex, "modifiedIndex": $modifiedIndex "isDirectory": $isDirectory, "expiration": $expiration,"ttl":${ttl != null ? ttl.inSeconds :null}, "value": $value, "nodes" : $nodes';
  }

}


/**
 * A client that provides operations on an etcd server.
 */
class EtcdClient {

  final String _host;
  final int _port;

  HttpClient _client = new HttpClient();
  bool _closed = false;
  Map<StreamController, HttpClient> _watchers = {};


  EtcdClient({host: '127.0.0.1', port: 4001})
      : this._host = host,
        this._port = port;

  /**
   * Returns the [Node] at [path].
   * 
   * Returns a [Future] which completes either with a [Node] or an [ErrorCode].
   * If the [Node] is a directory, the returned [Node] will contain the
   * files in the directory and a listing of the subdirectories.  If
   * [recursive] is true, then the entire subdirectory structure is
   * be returned.
   *  
   **/
  Future<Node> getNode(String path, {recursive: false}) {
    var completer = new Completer();
    _get(path, _client, _host, _port, options: {
      'recursive': recursive
    }).then((result) {
      if (result['errorCode'] == null) {
        completer.complete(_jsonToNode(result['node']));
      } else {
        completer.completeError(_lookupErrorCode(result['errorCode']));
      }
    }).catchError((error, st) {
      completer.completeError(error, st);
    });
    return completer.future;
  }

  /**
   * Set the node at path.
   * 
   * Returns a [Future] which completes with the [NodeEvent] generated by setting the node at [path] with the options specified. 
   * 
   * * [value] is ignored if directory is true
   * 
   * TODO: Document nuanced behaviors
   */
  Future<NodeEvent> setNode(String path, {dynamic value, Duration ttl, bool hidden, bool directory}) {
    _assertOpen();
    var completer = new Completer();
    _put(path, options: {
      'value': value,
      'ttl': ttl,
      'dir': directory,
      'hidden': hidden
    }).then((result) {
      if (result['errorCode'] == null) {

        completer.complete(_jsonToNodeEvent(result));

      } else {
        completer.completeError(_lookupErrorCode(result['errorCode']));
      }
    }).catchError((error, st) {
      completer.completeError(error, st);
    });
    return completer.future;
  }

  /**
   * Delete the [Node] at [path].
   * 
   * Returns a [Future] which completes with the [NodeEvent] generated as the
   * result of deleting the node at [path].
   * 
   *  * [recursive] must be true to delete directories with children
   */
  Future<NodeEvent> deleteNode(String path, {bool recursive: false}) {
    _assertOpen();
    var completer = new Completer();
    _delete(path, options: {
      'recursive': recursive
    }).then((result) {
      if (result['errorCode'] == null) {
        completer.complete(_jsonToNodeEvent(result));
      } else {
        completer.complete(_lookupErrorCode(result['errorCode']));
      }
    }).catchError((error, stacktrace) {
      completer.completeError(error, stacktrace);
    }).catchError((error, st) {
      completer.completeError(error, st);
    });
    return completer.future;
  }

  /**
   * Watch the [Node] at [path] for [NodeEvent]'s.
   * 
   * Returns a [Stream] of [NodeEvent]'s occurring at path.  
   * 
   *  * Set [recursive] to true to watch all changes in a directory structure
   * 
   **/
  Stream<NodeEvent> watch(String path, {int waitIndex, bool recursive}) {
    _assertOpen();
    var controller;
    controller = new StreamController(onListen: () {
      _watchers[controller] = new HttpClient();
      _watch(path, waitIndex, recursive, controller);
    }, onCancel: () {
      //TODO Is there any need to close the controller?
      _watchers.remove(controller).close(force: true);
    });
    return controller.stream;
  }
  
  
  /**
   * Close the client, releasing all resources.
   * 
   * Closes the client, forcing resources to be released.  Failing
   * to close the client may result in unreleased resources and
   * VM's that do not shutdown gracefully.
   */
  close() {
    _assertOpen();
    _client.close(force: true);
    _watchers.forEach((k, v) {
      k.close();
      v.close(force: true);
    });
  }

  _watch(String path, int waitIndex, bool recursive, StreamController controller) {
    _get(path, _watchers[controller], _host, _port, options: {
      'wait': true,
      'waitIndex': waitIndex,
      'recursive': recursive
    }).then((json) {
      if (_watchers.containsKey(controller)) {
        var event = _jsonToNodeEvent(json);
        controller.add(event);
        if (event.type == NodeEventType.DELETED) {
          // Etcd propagates changes to the parent directory for watched nodes, 
          // but the index is the index of the parent node. So, we keep the current 
          // waitIndex if this the event is for a prefix.
          //
          if (event.oldValue.key.startsWith(path)) {
            _watch(path, event.oldValue.modifiedIndex + 1, recursive, controller);
          } else {
            _watch(path, waitIndex, recursive, controller);
          }
        } else {
          if (event.newValue.key.startsWith(path)) {
            _watch(path, event.newValue.modifiedIndex + 1, recursive, controller);
          } else {
            _watch(path, waitIndex, recursive, controller);
          }
        }
      }
    }).catchError((e, ss) {
      controller.addError(e, ss);
    });
  }

  Future<Map> _put(String key, {Map options: const {}}) {
    var completer = new Completer();
    _client.put(_host, _port, _keyToPath(key)).then((request) {
      request.headers.contentType = ContentType.parse('application/x-www-form-urlencoded');
      request.headers.set('accept', '*/*');
      var buffer = new StringBuffer();

      _addQueryString(options, buffer);

      var contentString = buffer.toString();
      request.contentLength = contentString.length;
      request.write(contentString);
      request.close().then((response) {
        UTF8.decodeStream(response).then((jsonString) {
          completer.complete(JSON.decode(jsonString));
        });

      });
    }).catchError((error, stacktrace) {
      completer.completeError(error, stacktrace);
    });
    return completer.future;
  }


  static Future _get(String key, HttpClient client, String host, int port, {Map options: const {}}) {
    var buffer = new StringBuffer();
    buffer.write(_keyToPath(key));
    _addQueryString(options, buffer);
    var urlString = buffer.toString();
    var completer = new Completer();
    client.get(host, port, urlString).then((request) {

      request.close().then((response) {

        UTF8.decodeStream(response).then((jsonString) {
          completer.complete(JSON.decode(jsonString));
        });
      });

    }).catchError((error, stacktrace) {
      completer.completeError(error, stacktrace);
    });
    return completer.future;
  }

  Future _delete(String key, {Map options: const {}}) {
    var buffer = new StringBuffer();
    buffer.write(_keyToPath(key));
    _addQueryString(options, buffer);
    var urlString = buffer.toString();
    var completer = new Completer();
    _client.delete(_host, _port, urlString).then((request) {

      request.close().then((response) {
        UTF8.decodeStream(response).then((jsonString) {
          completer.complete(JSON.decode(jsonString));
        });
      });

    }).catchError((error, stacktrace) {
      completer.completeError(error, stacktrace);
    });
    return completer.future;
  }

  _assertOpen() {
    if (_closed) {
      throw new StateError('Attempted to close an already closed client.');
    }
  }

  static String _keyToPath(String key) {
    return '/v2/keys$key';
  }

  static _addKeyValue(String key, dynamic value, StringBuffer buffer) {
    if (value != null) {
      if (buffer.isEmpty) {
        buffer.write('${key}=${value}');
      } else {
        buffer.write('&${key}=${value}');
      }
    }
  }

  static void _addQueryString(Map options, StringBuffer buffer) {
    if (options.isNotEmpty) {
      buffer.write('?');
      bool first = true;
      options.forEach((k, v) {
        if (v != null) {
          buffer.write('&$k=$v');
        }

      });
    }
  }


  static NodeEvent _jsonToNodeEvent(Map json) {
    if (json['action'] == 'set') {
      if (json['prevNode'] != null) {
        return new NodeEvent(NodeEventType.MODIFIED, newValue: _jsonToNode(json['node']), oldValue: _jsonToNode(json['prevNode']));
      } else {
        return new NodeEvent(NodeEventType.CREATED, newValue: _jsonToNode(json['node']));
      }
    } else if (json['action'] == 'delete') {
      return new NodeEvent(NodeEventType.DELETED, oldValue: _jsonToNode(json['prevNode']));
    } else if (json['action'] == 'create') {
      return new NodeEvent(NodeEventType.CREATED, newValue: _jsonToNode(json['node']));
    } else if (json['action'] == 'update') {
      return new NodeEvent(NodeEventType.MODIFIED, newValue: _jsonToNode(json['node']), oldValue: _jsonToNode(json['prevNode']));
    } else {
      throw new StateError('Unknown action type [${json['action']}]');
    }

  }

  static Node _jsonToNode(Map json) {
    if (json['dir'] == true) {
      var nodes = [];
      if (json['nodes'] != null) {
        for (var node in json['nodes']) {
          nodes.add(_jsonToNode(node));
        }
      }
      return new Node(json['key'], json['createdIndex'], json['modifiedIndex'], isDirectory: true, expiration: json['expiration'] != null ? _FORMAT.parse(json['expiration'].substring(0, 23), true) : null, ttl: json['ttl'] != null ? new Duration(seconds: json['ttl']) : null, nodes: nodes);
    } else {
      return new Node(json['key'], json['createdIndex'], json['modifiedIndex'], isDirectory: false, expiration: json['expiration'] != null ? _FORMAT.parse(json['expiration'].substring(0, 23), true) : null, ttl: json['ttl'] != null ? new Duration(seconds: json['ttl']) : null, value: json['value']);
    }


  }

}
