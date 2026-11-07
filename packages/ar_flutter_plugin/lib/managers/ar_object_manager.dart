import 'dart:typed_data';

import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/utils/json_converters.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

// Type definitions to enforce a consistent use of the API
typedef NodeTapResultHandler = void Function(List<String> nodes);
typedef NodePanStartHandler = void Function(String node);
typedef NodePanChangeHandler = void Function(String node);
typedef NodePanEndHandler = void Function(String node, Matrix4 transform);
typedef NodeRotationStartHandler = void Function(String node);
typedef NodeRotationChangeHandler = void Function(String node);
typedef NodeRotationEndHandler = void Function(String node, Matrix4 transform);

/// Manages the all node-related actions of an [ARView]
class ARObjectManager {
  /// Platform channel used for communication from and to [ARObjectManager]
  late MethodChannel _channel;

  /// Debugging status flag. If true, all platform calls are printed. Defaults to false.
  final bool debug;

  /// Callback function that is invoked when the platform detects a tap on a node
  NodeTapResultHandler? onNodeTap;
  NodePanStartHandler? onPanStart;
  NodePanChangeHandler? onPanChange;
  NodePanEndHandler? onPanEnd;
  NodeRotationStartHandler? onRotationStart;
  NodeRotationChangeHandler? onRotationChange;
  NodeRotationEndHandler? onRotationEnd;

  ARObjectManager(int id, {this.debug = false}) {
    _channel = MethodChannel('arobjects_$id');
    _channel.setMethodCallHandler(_platformCallHandler);
    if (debug) {
      print("ARObjectManager initialized");
    }
  }

  Future<void> _platformCallHandler(MethodCall call) {
    if (debug) {
      print('_platformCallHandler call ${call.method} ${call.arguments}');
    }
    try {
      switch (call.method) {
        case 'onError':
          print(call.arguments);
          break;
        case 'onNodeTap':
          if (onNodeTap != null) {
            final tappedNodes = call.arguments as List<dynamic>;
            onNodeTap!(tappedNodes
                .map((tappedNode) => tappedNode.toString())
                .toList());
          }
          break;
        case 'onPanStart':
          if (onPanStart != null) {
            final tappedNode = call.arguments as String;
            // Notify callback
            onPanStart!(tappedNode);
          }
          break;
        case 'onPanChange':
          if (onPanChange != null) {
            final tappedNode = call.arguments as String;
            // Notify callback
            onPanChange!(tappedNode);
          }
          break;
        case 'onPanEnd':
          if (onPanEnd != null) {
            final tappedNodeName = call.arguments["name"] as String;
            final transform =
                MatrixConverter().fromJson(call.arguments['transform'] as List);

            // Notify callback
            onPanEnd!(tappedNodeName, transform);
          }
          break;
        case 'onRotationStart':
          if (onRotationStart != null) {
            final tappedNode = call.arguments as String;
            onRotationStart!(tappedNode);
          }
          break;
        case 'onRotationChange':
          if (onRotationChange != null) {
            final tappedNode = call.arguments as String;
            onRotationChange!(tappedNode);
          }
          break;
        case 'onRotationEnd':
          if (onRotationEnd != null) {
            final tappedNodeName = call.arguments["name"] as String;
            final transform =
                MatrixConverter().fromJson(call.arguments['transform'] as List);

            // Notify callback
            onRotationEnd!(tappedNodeName, transform);
          }
          break;
        default:
          if (debug) {
            print('Unimplemented method ${call.method} ');
          }
      }
    } catch (e) {
      print('Error caught: ' + e.toString());
    }
    return Future.value();
  }

  /// Sets up the AR Object Manager
  onInitialize() {
    _channel.invokeMethod<void>('init', {});
  }

  /// Add given node to the given anchor of the underlying AR scene (or to its top-level if no anchor is given) and listen to any changes made to its transformation
  Future<bool?> addNode(ARNode node, {ARPlaneAnchor? planeAnchor}) async {
    try {
      node.transformNotifier.addListener(() {
        _channel.invokeMethod<void>('transformationChanged', {
          'name': node.name,
          'transformation':
              MatrixValueNotifierConverter().toJson(node.transformNotifier)
        });
      });
      if (planeAnchor != null) {
        planeAnchor.childNodes.add(node.name);
        return await _channel.invokeMethod<bool>('addNodeToPlaneAnchor',
            {'node': node.toMap(), 'anchor': planeAnchor.toJson()});
      } else {
        return await _channel.invokeMethod<bool>('addNode', node.toMap());
      }
    } on PlatformException catch (e) {
      return false;
    }
  }

  /// Lists the animation clips packaged in a bundled GLB asset.
  Future<List<Map<dynamic, dynamic>>> getAnimations(ARNode node) async {
    final animations = await _channel.invokeListMethod<dynamic>(
      'getAnimations',
      {'name': node.name},
    );
    return (animations ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => Map<dynamic, dynamic>.from(item))
        .toList();
  }

  /// Starts a named animation clip on a bundled GLB asset.
  Future<bool?> playAnimation(
    ARNode node,
    String animation, {
    bool loop = false,
  }) =>
      _channel.invokeMethod<bool>('playAnimation', {
        'name': node.name,
        'animation': animation,
        'loop': loop,
      });

  /// Lets the character wander on its floor anchor while it is out of view.
  Future<void> setRoamingEnabled(ARNode node, bool enabled) =>
      _channel.invokeMethod<void>('setRoamingEnabled', {
        'name': node.name,
        'enabled': enabled,
      });

  /// Starts one short walk or run along the character's current floor anchor.
  Future<bool?> triggerRoaming(ARNode node) =>
      _channel.invokeMethod<bool>('triggerRoaming', {'name': node.name});

  Future<bool?> callTowardCamera(ARNode node) =>
      _channel.invokeMethod<bool>('callTowardCamera', {'name': node.name});

  /// Animates the character toward a tapped world position.
  Future<bool?> moveTo(ARNode node, Matrix4 worldTransform) =>
      _channel.invokeMethod<bool>('moveTo', {
        'name': node.name,
        'transformation': const MatrixConverter().toJson(worldTransform),
      });

  /// Remove given node from the AR Scene
  Future<void> removeNode(ARNode node) async {
    await _channel.invokeMethod<void>('removeNode', {'name': node.name});
  }
}
