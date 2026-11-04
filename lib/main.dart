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
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

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
    movement: 'El otorongo te da la bienvenida',
    script:
        '¡Hola, hola! ¡Qué alegría tenerlos por aquí! ¡Bienvenidos al '
        'Encuentro Regional Amazónico de Incubadoras y Emprendimientos San '
        'Martín 2026! Soy el anfitrión de BioInnova San Martín y hoy los '
        'acompañaré en esta gran experiencia de innovación y emprendimiento.',
    animationKeywords: ['wave'],
    directionIcon: Icons.waving_hand_rounded,
  ),
  _GuideScene(
    title: 'Jornada y Speed Mentoring',
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
    required this.animationKeywords,
    required this.directionIcon,
    this.facingYaw = 0,
  });

  final String title;
  final String movement;
  final String script;
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
  final FlutterTts _tts = FlutterTts();
  final List<_CharacterAnimation> _animations = [];
  Timer? _animationTimer;
  bool _placed = false;
  bool _busy = false;
  bool _sound = true;
  String _status = 'Toca la pantalla para hacer aparecer al tigrillo';
  int _autoAnimationIndex = 0;
  int _currentGuideScene = 0;
  int _guidePlaybackId = 0;

  @override
  void initState() {
    super.initState();
    _configureVoice();
  }

  Future<void> _configureVoice() async {
    await _tts.setLanguage('es-MX');
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final spanish = voices.whereType<Map>().where((voice) {
          final locale = '${voice['locale']}'.toLowerCase().replaceAll(
            '_',
            '-',
          );
          return locale == 'es-419' ||
              [
                'es-pe',
                'es-mx',
                'es-us',
                'es-co',
                'es-ar',
                'es-cl',
              ].contains(locale);
        }).toList();
        for (final preferred in [
          'es-pe',
          'es-mx',
          'es-419',
          'es-co',
          'es-us',
          'es-ar',
          'es-cl',
        ]) {
          final matches = spanish.where(
            (voice) =>
                '${voice['locale']}'.toLowerCase().replaceAll('_', '-') ==
                preferred,
          );
          if (matches.isEmpty) continue;
          final voice = matches.first;
          await _tts.setVoice({
            'name': '${voice['name']}',
            'locale': '${voice['locale']}',
          });
          break;
        }
      }
    } catch (error) {
      debugPrint('Se usará la voz latinoamericana predeterminada: $error');
    }
    await _tts.setSpeechRate(.52);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1);
    await _tts.awaitSpeakCompletion(true);
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
      _setStatus(
        _placed
            ? 'Apunta al suelo o a una mesa y toca adonde debe ir.'
            : 'Apunta al suelo o a una mesa y toca la pantalla.',
      );
      return;
    }
    if (_placed) {
      final moved = await _objects?.moveTo(_tigrillo!, hit.worldTransform);
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

  Future<void> _playByKeyword(
    List<String> keywords, {
    int fallbackIndex = 0,
  }) async {
    if (_tigrillo == null || _animations.isEmpty) return;
    final lowered = keywords.map((word) => word.toLowerCase()).toList();
    final match = _animations.indexWhere(
      (animation) =>
          lowered.any((word) => animation.name.toLowerCase().contains(word)),
    );
    final index = match >= 0 ? match : fallbackIndex % _animations.length;
    final animation = _animations[index];
    await _objects?.playAnimation(_tigrillo!, animation.name, loop: true);
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
    final pauseMs = animation.durationMs.clamp(1600, 6200) + 350;
    _animationTimer = Timer(Duration(milliseconds: pauseMs), () async {
      if (!mounted || !_placed) return;
      if (_tigrillo == null) return;
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
    await _tts.stop();
    if (!mounted || playbackId != _guidePlaybackId) return;
    setState(() {
      _currentGuideScene = index;
      _status = 'Tu anfitrión de BioInnova';
    });
    await _playByKeyword(scene.animationKeywords, fallbackIndex: 0);
    if (!mounted || playbackId != _guidePlaybackId) return;
    if (_sound) await _speakNaturally(scene.script, playbackId);
    if (mounted && playbackId == _guidePlaybackId) {
      _scheduleAutoAnimation();
    }
  }

  Future<void> _speakNaturally(String script, int playbackId) async {
    final phrases = script
        .replaceAll('!', '!|')
        .replaceAll('?', '?|')
        .replaceAll('. ', '.|')
        .split('|')
        .map((phrase) => phrase.trim())
        .where((phrase) => phrase.isNotEmpty)
        .toList();
    for (var index = 0; index < phrases.length; index++) {
      if (!mounted || !_sound || playbackId != _guidePlaybackId) return;
      await _tts.speak(phrases[index]);
      if (index < phrases.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    }
  }

  Future<void> _removePlaced() async {
    if (_busy) return;
    if (mounted) setState(() => _busy = true);
    _guidePlaybackId++;
    _animationTimer?.cancel();
    try {
      await _tts.stop();
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

  @override
  void dispose() {
    _animationTimer?.cancel();
    _tts.stop();
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
            if (!_sound) _tts.stop();
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
                        'Descubre el encuentro conmigo',
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
          Row(
            children: [
              Expanded(
                child: _action(
                  Icons.my_location_rounded,
                  'Ubicar',
                  _removePlaced,
                  outline: true,
                ),
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
