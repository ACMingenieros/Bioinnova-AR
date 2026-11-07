import 'dart:async';
import 'dart:math' as math;

import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/models/ar_anchor.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'album_upload.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Brand.ink,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const TigrilloApp());
}

abstract final class Brand {
  static const ink = Color(0xff10241a);
  static const forest = Color(0xff087b42);
  static const leaf = Color(0xff1caf61);
  static const lime = Color(0xff9acb42);
  static const orange = Color(0xfff47c20);
  static const cream = Color(0xfffff7e9);
}

const _guideScenes = <_GuideScene>[
  _GuideScene(
    title: 'Bienvenida',
    audioAsset: 'assets/audio/introduccion.mp3',
    movement: 'El otorongo te da la bienvenida',
    script:
        '¡Hola, hola! ¡Qué alegría tenerlos por aquí! ¡Bienvenidos al '
        'Encuentro Regional Amazónico de Incubadoras y Emprendimientos San '
        'Martín 2026! Soy el anfitrión de BioInnova San Martín y hoy los '
        'acompañaré en esta gran experiencia de innovación y emprendimiento.',
    animationKeywords: ['heart'],
    directionIcon: Icons.waving_hand_rounded,
  ),
  _GuideScene(
    title: 'Jornada y Speed Mentoring',
    audioAsset: 'assets/audio/jornada_empresarial.mp3',
    movement: 'Señala hacia adelante',
    script:
        '¿Vienes a conectar, aprender y generar nuevas oportunidades? '
        '¡Entonces pasa adelante! Te esperamos en la Jornada Empresarial y '
        'el Speed Mentoring, donde grandes ideas se encuentran con nuevas '
        'oportunidades.',
    animationKeywords: ['cast'],
    directionIcon: Icons.arrow_upward_rounded,
  ),
  _GuideScene(
    title: 'Feria de emprendimientos',
    audioAsset: 'assets/audio/feria_emprendimientos.mp3',
    movement: 'Gira y señala a tu derecha',
    script:
        '¡Pero eso no es todo! Si quieres descubrir productos innovadores, '
        'conocer nuevos negocios y apoyar el talento emprendedor de nuestra '
        'Amazonía, ¡pasa a la derecha y visita nuestra Feria de '
        'Emprendimientos!',
    animationKeywords: ['cast'],
    directionIcon: Icons.arrow_forward_rounded,
    facingYaw: math.pi / 2,
  ),
  _GuideScene(
    title: 'Despedida',
    audioAsset: 'assets/audio/despedida.mp3',
    movement: 'El otorongo se despide',
    script:
        '¡Tenemos mucho por descubrir! Prepárate para conectar, compartir e '
        'innovar. ¡Disfruta del encuentro y que viva el emprendimiento '
        'amazónico! ¡Bienvenidos!',
    animationKeywords: ['wave'],
    directionIcon: Icons.celebration_rounded,
  ),
];

// Native Sceneform applies the character's final size.
const _tigrilloWorldScale = 1.0;

class _GuideScene {
  const _GuideScene({
    required this.title,
    required this.movement,
    required this.script,
    required this.audioAsset,
    required this.animationKeywords,
    required this.directionIcon,
    this.facingYaw = 0,
  });

  final String title;
  final String movement;
  final String script;
  final String audioAsset;
  final List<String> animationKeywords;
  final IconData directionIcon;
  final double facingYaw;
}

class TigrilloApp extends StatelessWidget {
  const TigrilloApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Tigrillo BioInnova',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Brand.forest,
        primary: Brand.forest,
        secondary: Brand.orange,
        surface: Brand.cream,
      ),
      scaffoldBackgroundColor: Brand.cream,
      fontFamily: 'Roboto',
    ),
    home: const WelcomePage(),
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Brand.ink,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Brand.ink,
    ),
    child: Scaffold(
      backgroundColor: Brand.ink,
      body: Stack(
        children: [
          const Positioned.fill(child: _WelcomeBackdrop()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/branding/bioinnova.png',
                      width: 194,
                      height: 58,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 214,
                      height: 214,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .16),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x5533aa63),
                            blurRadius: 60,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 164,
                            height: 164,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Brand.orange.withValues(alpha: .98),
                                  const Color(0xffbc4d14),
                                ],
                              ),
                            ),
                          ),
                          ClipOval(
                            child: Image.asset(
                              'assets/models/preview_tigrillo.png',
                              width: 204,
                              height: 204,
                              fit: BoxFit.cover,
                              cacheWidth: 612,
                            ),
                          ),
                          Positioned(
                            right: 14,
                            top: 26,
                            child: _sparkle(Icons.auto_awesome, Brand.lime),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 28,
                            child: _sparkle(Icons.eco_rounded, Brand.leaf),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Brand.leaf.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Brand.leaf.withValues(alpha: .36),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 15,
                          color: Brand.lime,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'EXPERIENCIA BIOINNOVA · SAN MARTÍN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tu encuentro\ncon la Amazonía.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tu anfitrión de BioInnova te espera. Descubre el encuentro, '
                    'escucha sus historias y explora a su lado.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _FeatureLine(
                    icon: Icons.view_in_ar_rounded,
                    label: 'Colócalo sobre el suelo de tu espacio',
                  ),
                  const SizedBox(height: 10),
                  _FeatureLine(
                    icon: Icons.record_voice_over_rounded,
                    label: 'Escucha su historia y mira sus movimientos',
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ARExperiencePage(),
                        ),
                      ),
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text(
                        'Conocer al tigrillo',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Brand.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'La cámara se activa solo al iniciar la experiencia',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  static Widget _sparkle(IconData icon, Color color) => Container(
    width: 39,
    height: 39,
    decoration: BoxDecoration(
      color: Brand.ink,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white.withValues(alpha: .7), width: 2),
    ),
    child: Icon(icon, size: 20, color: color),
  );
}

class _WelcomeBackdrop extends StatelessWidget {
  const _WelcomeBackdrop();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff173e2b), Brand.ink, Color(0xff08170f)],
        stops: [0, .57, 1],
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          top: -110,
          right: -80,
          child: Container(
            width: 310,
            height: 310,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Brand.leaf.withValues(alpha: .08),
            ),
          ),
        ),
        Positioned(
          top: 180,
          left: -130,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Brand.orange.withValues(alpha: .06),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: Brand.lime, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    ],
  );
}

class ARExperiencePage extends StatefulWidget {
  const ARExperiencePage({super.key});

  @override
  State<ARExperiencePage> createState() => _ARExperiencePageState();
}

class _ARExperiencePageState extends State<ARExperiencePage> {
  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchorsManager;
  ARPlaneAnchor? _anchor;
  ARNode? _tigrillo;
  final AudioPlayer _narration = AudioPlayer();
  StreamSubscription<void>? _narrationCompletedSubscription;
  Completer<void>? _narrationFinished;
  final List<_CharacterAnimation> _animations = [];
  Timer? _animationTimer;
  Timer? _gestureTimer;
  bool _speaking = false;
  bool _jumping = false;
  bool _placed = false;
  bool _busy = false;
  bool _capturingPhoto = false;
  Uint8List? _photoBytes;
  bool _sound = true;
  String _status = 'Toca la pantalla para hacer aparecer al tigrillo';
  int _autoAnimationIndex = 0;
  int _currentGuideScene = 0;
  int _guidePlaybackId = 0;

  @override
  void initState() {
    super.initState();
    _narrationCompletedSubscription = _narration.onPlayerComplete.listen((_) {
      _finishNarration();
    });
  }

  void _finishNarration() {
    final pending = _narrationFinished;
    if (pending != null && !pending.isCompleted) pending.complete();
    _narrationFinished = null;
  }

  Future<void> _stopNarration() async {
    _finishNarration();
    await _narration.stop();
  }

  void _onARCreated(
    ARSessionManager session,
    ARObjectManager objects,
    ARAnchorManager anchors,
    dynamic locationManager,
  ) {
    _session = session;
    _objects = objects;
    _anchorsManager = anchors;
    session.onInitialize(
      showFeaturePoints: false,
      showPlanes: false,
      showWorldOrigin: false,
      handleTaps: true,
      handlePans: false,
      handleRotation: false,
    );
    objects.onInitialize();
    objects.onNodeTap = (names) {
      if (names.contains(_tigrillo?.name)) _playSurpriseJump();
    };
    session.onPlaneOrPointTap = _onSurfaceTap;
    _setStatus('Toca la pantalla para hacer aparecer al tigrillo');
  }

  Future<void> _onSurfaceTap(List<ARHitTestResult> hits) async {
    if (_busy) return;
    final hit = hits
        .where(
          (item) =>
              item.type == ARHitTestResultType.plane ||
              item.type == ARHitTestResultType.instant,
        )
        .firstOrNull;
    if (hit == null) {
      if (_placed && _tigrillo != null) {
        final moved = await _objects?.callTowardCamera(_tigrillo!);
        _setStatus(
          moved == true
              ? '¡Voy hacia ti!'
              : 'Apunta al suelo y toca para moverme.',
        );
        return;
      }
      _setStatus(
        _placed
            ? 'Apunta al suelo o a una mesa y toca adonde debe ir.'
            : 'Apunta al suelo o a una mesa y toca la pantalla.',
      );
      return;
    }
    if (_placed) {
      _animationTimer?.cancel();
      _gestureTimer?.cancel();
      final moved = await _objects?.moveTo(_tigrillo!, hit.worldTransform);
      if (moved != true) await _objects?.callTowardCamera(_tigrillo!);
      _setStatus(
        moved == true
            ? '¡Allá voy! Toca otro lugar para moverme.'
            : 'Toca otro punto de la superficie para moverme.',
      );
      return;
    }
    await _placeOn(hit);
  }

  Future<void> _placeOn(ARHitTestResult hit) async {
    if (_busy || _anchorsManager == null || _objects == null) return;
    setState(() {
      _busy = true;
      _status = 'Preparando el tigrillo…';
    });
    try {
      final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
      if (await _anchorsManager!.addAnchor(anchor) != true) {
        _setStatus('No pude fijarlo ahí. Toca otra zona del suelo.');
        return;
      }
      final node = ARNode(
        type: NodeType.assetGLB,
        uri: 'assets/models/tigrillo.glb',
        name: 'bioinnova-tigrillo',
        scale: vm.Vector3.all(_tigrilloWorldScale),
        position: vm.Vector3(0, 0, 0),
        rotation: vm.Vector4(0, 1, 0, 0),
      );
      if (await _objects!.addNode(node, planeAnchor: anchor) != true) {
        await _anchorsManager!.removeAnchor(anchor);
        _setStatus('No se pudo cargar el modelo 3D.');
        return;
      }
      _anchor = anchor;
      _tigrillo = node;
      if (mounted) {
        setState(() {
          _placed = true;
          _status = hit.type == ARHitTestResultType.instant
              ? 'Ubicación aproximada: acércate o aléjate para ajustar la vista.'
              : '¡Listo! El tigrillo está anclado al suelo.';
        });
      }
      await _loadAnimations(node);
      await _objects?.setRoamingEnabled(node, false);
      _setStatus('Toca otro lugar de la cámara para que vaya hacia allí.');
      if (mounted) setState(() => _busy = false);
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted || !_placed || _tigrillo != node) return;
      await _playGuideScene(0);
    } catch (error) {
      _setStatus('No pude iniciar la experiencia: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadAnimations(ARNode node) async {
    final available = await _objects?.getAnimations(node) ?? const [];
    _animations
      ..clear()
      ..addAll(available.map(_CharacterAnimation.fromMap));
    if (_animations.isEmpty) {
      debugPrint('El motor no devolvió clips de animación para el GLB.');
    }
  }

  Future<_CharacterAnimation?> _playByKeyword(
    List<String> keywords, {
    int fallbackIndex = 0,
    bool loop = true,
  }) async {
    if (_tigrillo == null || _animations.isEmpty) return null;
    final lowered = keywords.map((word) => word.toLowerCase()).toList();
    final match = _animations.indexWhere(
      (animation) =>
          lowered.any((word) => animation.name.toLowerCase().contains(word)),
    );
    final index = match >= 0 ? match : fallbackIndex % _animations.length;
    final animation = _animations[index];
    final played = await _objects?.playAnimation(
      _tigrillo!,
      animation.name,
      loop: loop,
    );
    return played == true ? animation : null;
  }

  void _scheduleAutoAnimation() {
    _animationTimer?.cancel();
    if (!_placed || _animations.isEmpty) return;
    final candidates = _animations
        .where((animation) => animation.name.toLowerCase().contains('wave'))
        .toList();
    if (candidates.isEmpty) return;
    final animation = candidates[_autoAnimationIndex % candidates.length];
    _autoAnimationIndex++;
    const pauseMs = 14000;
    _animationTimer = Timer(Duration(milliseconds: pauseMs), () async {
      if (!mounted || !_placed) return;
      if (_tigrillo == null) return;
      if (_speaking || _jumping) {
        _scheduleAutoAnimation();
        return;
      }
      await _objects?.playAnimation(_tigrillo!, animation.name, loop: false);
      _animationTimer = Timer(
        Duration(milliseconds: animation.durationMs.clamp(900, 5000)),
        () async {
          if (!mounted || !_placed || _tigrillo == null) return;
          await _playByKeyword(['talk']);
          _scheduleAutoAnimation();
        },
      );
    });
  }

  Future<void> _playGuideScene(int index) async {
    if (!_placed || _tigrillo == null) return;
    final scene = _guideScenes[index];
    final playbackId = ++_guidePlaybackId;
    _animationTimer?.cancel();
    _gestureTimer?.cancel();
    _speaking = false;
    await _stopNarration();
    if (!mounted || playbackId != _guidePlaybackId) return;
    setState(() {
      _currentGuideScene = index;
      _status = 'Tu anfitrión de BioInnova';
    });
    _speaking = _sound;
    final gesture = await _playByKeyword(
      scene.animationKeywords,
      fallbackIndex: 0,
      loop: false,
    );
    if (gesture != null) {
      _gestureTimer = Timer(
        Duration(milliseconds: gesture.durationMs.clamp(900, 10000)),
        () {
          if (mounted && playbackId == _guidePlaybackId && !_jumping) {
            _playByKeyword(['talk']);
          }
        },
      );
    }
    if (!mounted || playbackId != _guidePlaybackId) return;
    if (_sound) await _playNarration(scene.audioAsset, playbackId);
    if (!mounted || playbackId != _guidePlaybackId) return;
    _speaking = false;
    if (mounted && playbackId == _guidePlaybackId) {
      if (index == 0 || index == _guideScenes.length - 1) {
        await _playSurpriseJump();
      } else {
        _scheduleAutoAnimation();
      }
    }
  }

  Future<void> _playSurpriseJump() async {
    if (_jumping || !_placed || _busy || _tigrillo == null) return;
    final clip = _animations
        .where((item) => item.name.toLowerCase().contains('backflip'))
        .firstOrNull;
    if (clip == null) return;
    final node = _tigrillo!;
    final playbackId = _guidePlaybackId;
    _animationTimer?.cancel();
    _gestureTimer?.cancel();
    _jumping = true;
    try {
      final played = await _objects?.playAnimation(
        node,
        clip.name,
        loop: false,
      );
      if (played != true) return;
      await Future<void>.delayed(Duration(milliseconds: clip.durationMs));
      if (mounted &&
          _placed &&
          _tigrillo == node &&
          playbackId == _guidePlaybackId) {
        await _playByKeyword(['talk']);
        _scheduleAutoAnimation();
      }
    } catch (error) {
      debugPrint('No se pudo reproducir la voltereta: $error');
    } finally {
      _jumping = false;
    }
  }

  Future<void> _playNarration(String asset, int playbackId) async {
    try {
      if (!mounted || !_sound || playbackId != _guidePlaybackId) return;
      final finished = Completer<void>();
      _narrationFinished = finished;
      await _narration.play(AssetSource(asset.substring('assets/'.length)));
      await finished.future;
    } catch (error) {
      debugPrint('No se pudo reproducir la narración $asset: $error');
      if (mounted && playbackId == _guidePlaybackId) {
        _setStatus('No se pudo reproducir el audio. Toca Repetir.');
      }
    }
  }

  Future<void> _removePlaced() async {
    if (_busy) return;
    if (mounted) setState(() => _busy = true);
    _guidePlaybackId++;
    _animationTimer?.cancel();
    _gestureTimer?.cancel();
    _speaking = false;
    try {
      await _stopNarration();
      final node = _tigrillo;
      if (node != null) {
        await _objects?.setRoamingEnabled(node, false);
        await _objects?.removeNode(node);
      }
      final anchor = _anchor;
      if (anchor != null) await _anchorsManager?.removeAnchor(anchor);
      _tigrillo = null;
      _anchor = null;
      if (mounted) {
        setState(() {
          _placed = false;
          _currentGuideScene = 0;
          _status = 'Toca la pantalla para hacer aparecer al tigrillo';
        });
      }
    } catch (error) {
      _setStatus('No pude volver a ubicarlo. Intenta de nuevo.');
      debugPrint('Error al retirar el tigrillo: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _status = value);
  }

  Future<void> _takePhoto() async {
    if (!_placed || _busy || _capturingPhoto || _session == null) return;
    setState(() => _capturingPhoto = true);
    try {
      final bytes = await _session!.captureFramedPhoto();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (error) {
      debugPrint('No se pudo tomar la foto: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo tomar la foto: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturingPhoto = false);
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _gestureTimer?.cancel();
    _finishNarration();
    _narrationCompletedSubscription?.cancel();
    _narration.dispose();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Brand.ink,
    body: Stack(
      children: [
        Positioned.fill(
          child: ARView(
            onARViewCreated: _onARCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
            permissionPromptDescription: 'Necesitamos la cámara para ver tu espacio y colocar al tigrillo en el suelo.',
            permissionPromptButtonText: 'Permitir cámara',
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Brand.ink.withValues(alpha: .35),
                    Colors.transparent,
                    Colors.transparent,
                    Brand.ink.withValues(alpha: .55),
                  ],
                  stops: const [0, .23, .57, 1],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _topBar(),
              const Spacer(),
              if (!_placed) IgnorePointer(child: _targetReticle()),
              const Spacer(),
              _bottomPanel(),
            ],
          ),
        ),
        if (_busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(
                child: CircularProgressIndicator(color: Brand.orange),
              ),
            ),
          ),
        if (_photoBytes != null && _session != null)
          Positioned.fill(
            child: _PhotoPreviewPage(
              bytes: _photoBytes!,
              session: _session!,
              onClose: () => setState(() => _photoBytes = null),
            ),
          ),
      ],
    ),
  );

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
    child: Row(
      children: [
        _roundButton(Icons.arrow_back_rounded, () {
          Navigator.of(context).maybePop();
        }),
        const SizedBox(width: 11),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BIOINNOVA · RA',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Tigrillo de San Martín',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _roundButton(
          _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          () {
            setState(() => _sound = !_sound);
            if (!_sound) {
              _guidePlaybackId++;
              _speaking = false;
              _stopNarration();
            }
          },
        ),
      ],
    ),
  );

  Widget _targetReticle() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 184,
        height: 132,
        decoration: BoxDecoration(
          border: Border.all(
            color: Brand.lime.withValues(alpha: .85),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Align(alignment: Alignment.topLeft, child: _corner()),
            Align(
              alignment: Alignment.topRight,
              child: Transform.rotate(angle: 1.5708, child: _corner()),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Transform.rotate(angle: -1.5708, child: _corner()),
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Transform.rotate(angle: 3.1415, child: _corner()),
            ),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: .65, end: 1.0),
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const Icon(
                  Icons.touch_app_rounded,
                  color: Brand.orange,
                  size: 44,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 11),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xe811281c),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                color: Brand.orange,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _status,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _corner() => Container(
    width: 20,
    height: 20,
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: Brand.lime, width: 3),
        left: BorderSide(color: Brand.lime, width: 3),
      ),
      borderRadius: BorderRadius.only(topLeft: Radius.circular(9)),
    ),
  );

  Widget _bottomPanel() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_placed)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 11),
            decoration: BoxDecoration(
              color: const Color(0xe811281c),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 48,
                  child: _currentGuideScene == 1 || _currentGuideScene == 2
                      ? _PulsingDirectionArrow(
                          icon: _guideScenes[_currentGuideScene].directionIcon,
                          isRight: _currentGuideScene == 2,
                        )
                      : Icon(
                          _guideScenes[_currentGuideScene].directionIcon,
                          color: Brand.orange,
                          size: 30,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _guideScenes[_currentGuideScene].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .35,
                        ),
                      ),
                      Text(
                        _currentGuideScene == 0
                            ? 'Tócame para verme saltar'
                            : 'Descubre el encuentro conmigo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (_placed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _capturingPhoto ? null : _takePhoto,
                icon: const Icon(Icons.photo_camera_rounded, size: 23),
                label: Text(
                  _capturingPhoto ? 'Preparando foto…' : 'Tomar foto',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Brand.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        if (_placed)
          Row(
            children: [
              Expanded(
                child: _action(Icons.my_location_rounded, 'Ven aquí', () async {
                  if (_tigrillo != null) {
                    await _objects?.callTowardCamera(_tigrillo!);
                  }
                }, outline: true),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _action(
                  Icons.replay_rounded,
                  'Repetir',
                  () => _playGuideScene(_currentGuideScene),
                  outline: true,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _action(
                  _currentGuideScene == _guideScenes.length - 1
                      ? Icons.restart_alt_rounded
                      : Icons.chevron_right_rounded,
                  _currentGuideScene == _guideScenes.length - 1
                      ? 'Inicio'
                      : 'Siguiente',
                  () => _playGuideScene(
                    (_currentGuideScene + 1) % _guideScenes.length,
                  ),
                ),
              ),
            ],
          )
        else
          const SizedBox(height: 8),
        const SizedBox(height: 9),
        Text(
          _placed ? _status : 'Apunta a una zona libre a 1–1,5 m y toca cualquier punto de la cámara.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _action(
    IconData icon,
    String label,
    VoidCallback onPressed, {
    bool outline = false,
  }) => SizedBox(
    height: 50,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: outline ? const Color(0xe811281c) : Brand.orange,
        foregroundColor: Colors.white,
        side: outline
            ? const BorderSide(color: Colors.white24)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );

  Widget _roundButton(IconData icon, VoidCallback tap) => Material(
    color: const Color(0xc911281c),
    shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
    child: InkWell(
      onTap: tap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 41,
        height: 41,
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    ),
  );
}

class _CharacterAnimation {
  const _CharacterAnimation({required this.name, required this.durationMs});

  final String name;
  final int durationMs;

  factory _CharacterAnimation.fromMap(Map<dynamic, dynamic> map) =>
      _CharacterAnimation(
        name: map['name']?.toString() ?? '',
        durationMs: (map['durationMs'] as num?)?.toInt() ?? 3000,
      );
}

class _PhotoPreviewPage extends StatefulWidget {
  const _PhotoPreviewPage({
    required this.bytes,
    required this.session,
    required this.onClose,
  });

  final Uint8List bytes;
  final ARSessionManager session;
  final VoidCallback onClose;

  @override
  State<_PhotoPreviewPage> createState() => _PhotoPreviewPageState();
}

class _PhotoPreviewPageState extends State<_PhotoPreviewPage> {
  String? _savedUri;
  bool _working = false;
  bool _uploading = false;
  bool _uploaded = false;

  Future<void> _upload() async {
    if (_uploading || _uploaded) return;
    setState(() => _uploading = true);
    try {
      await uploadPhotoToAlbum(widget.bytes);
      if (mounted) {
        setState(() => _uploaded = true);
        _message('Foto añadida al álbum del evento');
      }
    } catch (error) {
      _message('No se pudo subir al álbum: $error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _saveIfNeeded() async {
    if (_savedUri != null) return _savedUri;
    try {
      final uri = await widget.session.savePhoto(widget.bytes);
      if (mounted) setState(() => _savedUri = uri);
      return uri;
    } on PlatformException catch (error) {
      if (error.code == 'STORAGE_PERMISSION_REQUIRED') {
        final permission = await Permission.storage.request();
        if (permission.isGranted) {
          final uri = await widget.session.savePhoto(widget.bytes);
          if (mounted) setState(() => _savedUri = uri);
          return uri;
        }
        _message('Permite guardar fotos para continuar.');
        return null;
      }
      rethrow;
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      if (await _saveIfNeeded() != null) {
        _message('Foto guardada en Imágenes / BioInnova');
      }
    } catch (error) {
      _message('No se pudo guardar la foto: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _share() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      final uri = await _saveIfNeeded();
      if (uri != null) await widget.session.sharePhoto(uri);
    } catch (error) {
      _message('No se pudo compartir la foto: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Brand.ink,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cerrar foto',
                ),
                const SizedBox(width: 12),
                const Text(
                  'Tu foto con el tigrillo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Image.memory(
                widget.bytes,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _uploading || _uploaded ? null : _upload,
                    icon: Icon(
                      _uploaded
                          ? Icons.check_rounded
                          : Icons.cloud_upload_outlined,
                    ),
                    label: Text(
                      _uploaded
                          ? 'Foto en el álbum'
                          : _uploading
                          ? 'Subiendo al álbum…'
                          : 'Subir al álbum',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Brand.lime,
                      foregroundColor: Brand.ink,
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _save,
                        icon: Icon(
                          _savedUri == null
                              ? Icons.download_rounded
                              : Icons.check_rounded,
                        ),
                        label: Text(_savedUri == null ? 'Guardar' : 'Guardada'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          minimumSize: const Size(0, 52),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _working ? null : _share,
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Compartir'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.orange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PulsingDirectionArrow extends StatefulWidget {
  const _PulsingDirectionArrow({required this.icon, required this.isRight});

  final IconData icon;
  final bool isRight;

  @override
  State<_PulsingDirectionArrow> createState() => _PulsingDirectionArrowState();
}

class _PulsingDirectionArrowState extends State<_PulsingDirectionArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final distance = Curves.easeInOut.transform(_controller.value) * 5;
      return Transform.translate(
        offset: widget.isRight ? Offset(distance, 0) : Offset(0, -distance),
        child: child,
      );
    },
    child: Icon(widget.icon, color: Brand.lime, size: 32),
  );
}
