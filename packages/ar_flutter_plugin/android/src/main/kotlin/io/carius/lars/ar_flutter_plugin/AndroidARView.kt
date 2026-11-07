package io.carius.lars.ar_flutter_plugin

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Activity
import android.app.Application
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.provider.MediaStore
import android.util.Log
import android.view.MotionEvent
import android.view.PixelCopy
import android.view.View
import android.widget.Toast
import com.google.ar.core.*
import com.google.ar.core.exceptions.*
import com.google.ar.sceneform.*
import com.gorisse.thomas.sceneform.lightEstimationConfig
import com.gorisse.thomas.sceneform.light.LightEstimationConfig
import com.google.ar.sceneform.animation.ModelAnimator
import com.google.ar.sceneform.math.Vector3
import com.google.ar.sceneform.ux.*
import io.carius.lars.ar_flutter_plugin.Serialization.deserializeMatrix4
import io.carius.lars.ar_flutter_plugin.Serialization.serializeAnchor
import io.carius.lars.ar_flutter_plugin.Serialization.serializeHitResult
import io.carius.lars.ar_flutter_plugin.Serialization.serializePose
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.loader.FlutterLoader
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.nio.FloatBuffer
import java.util.concurrent.CompletableFuture
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.atan2

import android.R
import com.google.ar.sceneform.rendering.*

import android.view.ViewGroup

import com.google.ar.core.TrackingState














internal class AndroidARView(
        val activity: Activity,
        context: Context,
        messenger: BinaryMessenger,
        id: Int,
        creationParams: Map<String?, Any?>?
) : PlatformView {
    // constants
    private val TAG: String = AndroidARView::class.java.name
    private var isDisposed = false
    // Lifecycle variables
    private var mUserRequestedInstall = true
    lateinit var activityLifecycleCallbacks: Application.ActivityLifecycleCallbacks
    private val viewContext: Context
    // Platform channels
    private val sessionManagerChannel: MethodChannel = MethodChannel(messenger, "arsession_$id")
    private val objectManagerChannel: MethodChannel = MethodChannel(messenger, "arobjects_$id")
    private val anchorManagerChannel: MethodChannel = MethodChannel(messenger, "aranchors_$id")
    // UI variables
    private lateinit var arSceneView: ArSceneView
    private lateinit var transformationSystem: TransformationSystem
    private var showFeaturePoints = false
    private var showAnimatedGuide = false
    private lateinit var animatedGuide: View
    private var pointCloudNode = Node()
    private var worldOriginNode = Node()
    // Setting defaults
    private var enableRotation = false
    private var enablePans = false
    private var planeFindingMode = Config.PlaneFindingMode.DISABLED
    private var keepNodeSelected = true;
    private var footprintSelectionVisualizer = FootprintSelectionVisualizer()
    // Model builder
    private var modelBuilder = ArModelBuilder()
    private val activeAnimators = mutableMapOf<String, android.animation.ObjectAnimator>()
    private val appearanceAnimators = mutableMapOf<String, ValueAnimator>()
    private val roamingNodes = mutableSetOf<String>()
    private val roamingMovements = mutableMapOf<String, ValueAnimator>()
    private val orientationTurns = mutableMapOf<String, ValueAnimator>()
    private val outOfViewSince = mutableMapOf<String, Long>()
    private val lastRoamAt = mutableMapOf<String, Long>()
    // Cloud anchor handler
    private lateinit var cloudAnchorHandler: CloudAnchorHandler

    private lateinit var sceneUpdateListener: com.google.ar.sceneform.Scene.OnUpdateListener
    private lateinit var onNodeTapListener: com.google.ar.sceneform.Scene.OnPeekTouchListener

    // Method channel handlers
    private val onSessionMethodCall =
            object : MethodChannel.MethodCallHandler {
                override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                    Log.d(TAG, "AndroidARView onsessionmethodcall reveived a call!")
                    when (call.method) {
                        "init" -> {
                            initializeARView(call, result)
                        }
                        "getAnchorPose" -> {
                            val anchorNode = arSceneView.scene.findByName(call.argument("anchorId")) as AnchorNode?
                            if (anchorNode != null) {
                                result.success(serializePose(anchorNode.anchor!!.pose))
                            } else {
                                result.error("Error", "could not get anchor pose", null)
                            }
                        }
                        "getCameraPose" -> {
                            val cameraPose = arSceneView.arFrame?.camera?.displayOrientedPose
                            if (cameraPose != null) {
                                result.success(serializePose(cameraPose!!))
                            } else {
                                result.error("Error", "could not get camera pose", null)
                            }
                        }
                        "snapshot", "captureFramedPhoto" -> captureFrame(
                            result, call.method == "captureFramedPhoto",
                        )
                        "savePhoto" -> {
                            val bytes = call.argument<ByteArray>("bytes")
                            if (bytes == null) result.error("EMPTY_PHOTO", "No hay foto para guardar", null)
                            else try {
                                result.success(savePhoto(bytes).toString())
                            } catch (e: SecurityException) {
                                result.error("STORAGE_PERMISSION_REQUIRED", "Permite guardar fotos", null)
                            } catch (e: Exception) {
                                Log.e(TAG, "Unable to save AR photo", e)
                                result.error("SAVE_FAILED", e.localizedMessage, null)
                            }
                        }
                        "sharePhoto" -> {
                            val uri = call.argument<String>("uri")
                            if (uri == null) result.error("EMPTY_PHOTO", "No hay foto para compartir", null)
                            else try {
                                val send = Intent(Intent.ACTION_SEND).apply {
                                    type = "image/png"
                                    putExtra(Intent.EXTRA_STREAM, Uri.parse(uri))
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                activity.startActivity(Intent.createChooser(send, "Compartir foto BioInnova"))
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("SHARE_FAILED", e.localizedMessage, null)
                            }
                        }
                        "dispose" -> {
                            dispose()
                            result.success(null)
                        }
                        else -> {}
                    }
                }
            }
    private val onObjectMethodCall =
            object : MethodChannel.MethodCallHandler {
                override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                    Log.d(TAG, "AndroidARView onobjectmethodcall reveived a call!")
                    when (call.method) {
                        "init" -> {
                            // objectManagerChannel.invokeMethod("onError", listOf("ObjectTEST from
                            // Android"))
                        }
                        "addNode" -> {
                            val dict_node: HashMap<String, Any>? = call.arguments as? HashMap<String, Any>
                            dict_node?.let{
                                addNode(it).thenAccept{status: Boolean ->
                                    result.success(status)
                                }.exceptionally { throwable ->
                                    result.error("e", throwable.message, throwable.stackTrace)
                                    null
                                }
                            }
                        }
                        "addNodeToPlaneAnchor" -> {
                            val dict_node: HashMap<String, Any>? = call.argument<HashMap<String, Any>>("node")
                            val dict_anchor: HashMap<String, Any>? = call.argument<HashMap<String, Any>>("anchor")
                            if (dict_node != null && dict_anchor != null) {
                                addNode(dict_node, dict_anchor).thenAccept{status: Boolean ->
                                    result.success(status)
                                }.exceptionally { throwable ->
                                    result.error("e", throwable.message, throwable.stackTrace)
                                    null
                                }
                            } else {
                                result.success(false)
                            }

                        }
                        "removeNode" -> {
                            val nodeName: String? = call.argument<String>("name")
                            nodeName?.let{
                                stopCharacterAnimation(it)
                                appearanceAnimators.remove(it)?.cancel()
                                roamingNodes.remove(it)
                                roamingMovements.remove(it)?.cancel()
                                orientationTurns.remove(it)?.cancel()
                                outOfViewSince.remove(it)
                                lastRoamAt.remove(it)
                                if (transformationSystem.selectedNode?.name == nodeName){
                                    transformationSystem.selectNode(null)
                                    keepNodeSelected = true
                                }
                                val node = arSceneView.scene.findByName(nodeName)
                                node?.setParent(null)
                                result.success(null)
                            }
                        }
                        "getAnimations" -> {
                            val nodeName = call.argument<String>("name")
                            val renderable = nodeName?.let { findModelRenderable(it) }
                            val clips = if (renderable == null) emptyList() else
                                (0 until renderable.animationCount).map { index ->
                                    val data = renderable.getAnimation(index)
                                    hashMapOf("name" to data.name, "durationMs" to data.durationMillis)
                                }
                            result.success(clips)
                        }
                        "playAnimation" -> {
                            val nodeName = call.argument<String>("name")
                            val animationName = call.argument<String>("animation")
                            val loop = call.argument<Boolean>("loop") ?: false
                            result.success(
                                nodeName != null && animationName != null &&
                                    playCharacterAnimation(nodeName, animationName, loop),
                            )
                        }
                        "setRoamingEnabled" -> {
                            val nodeName = call.argument<String>("name")
                            val enabled = call.argument<Boolean>("enabled") ?: false
                            if (nodeName != null) {
                                if (enabled) {
                                    roamingNodes.add(nodeName)
                                    outOfViewSince.remove(nodeName)
                                    lastRoamAt.remove(nodeName)
                                } else {
                                    roamingNodes.remove(nodeName)
                                    roamingMovements.remove(nodeName)?.cancel()
                                    outOfViewSince.remove(nodeName)
                                }
                            }
                            result.success(null)
                        }
                        "triggerRoaming" -> {
                            val nodeName = call.argument<String>("name")
                            val node = nodeName?.let { arSceneView.scene.findByName(it) }
                            if (nodeName != null && node != null && !roamingMovements.containsKey(nodeName)) {
                                startRoamingMovement(nodeName, node)
                                lastRoamAt[nodeName] = SystemClock.elapsedRealtime()
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        }
                        "moveTo" -> {
                            val name = call.argument<String>("name")
                            val matrix = call.argument<ArrayList<Double>>("transformation")
                            val node = name?.let { arSceneView.scene.findByName(it) }
                            if (name == null || node == null || matrix == null || matrix.size < 15) {
                                result.success(false)
                            } else {
                                val target = Vector3(matrix[12].toFloat(), matrix[13].toFloat(), matrix[14].toFloat())
                                val camera = arSceneView.scene.camera
                                val cameraLocal = camera.worldToLocalPoint(node.worldPosition)
                                val screen = camera.worldToScreenPoint(node.worldPosition)
                                val outOfView = cameraLocal.z >= 0f || screen.x < 0f ||
                                    screen.x > arSceneView.width || screen.y < 0f || screen.y > arSceneView.height
                                val destination = if (outOfView) Vector3(
                                    camera.worldPosition.x + camera.forward.x * 1.35f,
                                    node.worldPosition.y,
                                    camera.worldPosition.z + camera.forward.z * 1.35f,
                                ) else Vector3(target.x, node.worldPosition.y, target.z)
                                result.success(animateCharacterTo(name, node, destination))
                            }
                        }
                        "callTowardCamera" -> {
                            val name = call.argument<String>("name")
                            val node = name?.let { arSceneView.scene.findByName(it) }
                            if (name == null || node == null) {
                                result.success(false)
                            } else {
                                val camera = arSceneView.scene.camera
                                val target = Vector3(
                                    camera.worldPosition.x + camera.forward.x * 1.35f,
                                    node.worldPosition.y,
                                    camera.worldPosition.z + camera.forward.z * 1.35f,
                                )
                                result.success(animateCharacterTo(name, node, target))
                            }
                        }
                        "transformationChanged" -> {
                            val nodeName: String? = call.argument<String>("name")
                            val newTransformation: ArrayList<Double>? = call.argument<ArrayList<Double>>("transformation")
                            nodeName?.let{ name ->
                                newTransformation?.let{ transform ->
                                    transformNode(name, transform)
                                    result.success(null)
                                }
                            }
                        }
                        else -> {}
                    }
                }
            }
    private val onAnchorMethodCall =
            object : MethodChannel.MethodCallHandler {
                override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
                    when (call.method) {
                        "addAnchor" -> {
                            val anchorType: Int? = call.argument<Int>("type")
                            if (anchorType != null){
                                when(anchorType) {
                                    0 -> { // Plane Anchor
                                        val transform: ArrayList<Double>? = call.argument<ArrayList<Double>>("transformation")
                                        val name: String? = call.argument<String>("name")
                                        if ( name != null && transform != null){
                                            result.success(addPlaneAnchor(transform, name))
                                        } else {
                                            result.success(false)
                                        }

                                    }
                                    else -> result.success(false)
                                }
                            } else {
                                result.success(false)
                            }
                        }
                        "removeAnchor" -> {
                            val anchorName: String? = call.argument<String>("name")
                            anchorName?.let{ name ->
                                removeAnchor(name)
                            }
                        }
                        "initGoogleCloudAnchorMode" -> {
                            if (arSceneView.session != null) {
                                val config = Config(arSceneView.session)
                                config.cloudAnchorMode = Config.CloudAnchorMode.ENABLED
                                config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                                config.focusMode = Config.FocusMode.AUTO
                                arSceneView.session?.configure(config)

                                cloudAnchorHandler = CloudAnchorHandler(arSceneView.session!!)
                            } else {
                                sessionManagerChannel.invokeMethod("onError", listOf("Error initializing cloud anchor mode: Session is null"))
                            }
                        }
                        "uploadAnchor" ->  {
                            val anchorName: String? = call.argument<String>("name")
                            val ttl: Int? = call.argument<Int>("ttl")
                            anchorName?.let {
                                val anchorNode = arSceneView.scene.findByName(anchorName) as AnchorNode?
                                if (ttl != null) {
                                    cloudAnchorHandler.hostCloudAnchorWithTtl(anchorName, anchorNode!!.anchor, cloudAnchorUploadedListener(), ttl!!)
                                } else {
                                    cloudAnchorHandler.hostCloudAnchor(anchorName, anchorNode!!.anchor, cloudAnchorUploadedListener())
                                }
                                //Log.d(TAG, "---------------- HOSTING INITIATED ------------------")
                                result.success(true)
                            }

                        }
                        "downloadAnchor" -> {
                            val anchorId: String? = call.argument<String>("cloudanchorid")
                            //Log.d(TAG, "---------------- RESOLVING INITIATED ------------------")
                            anchorId?.let {
                                cloudAnchorHandler.resolveCloudAnchor(anchorId, cloudAnchorDownloadedListener())
                            }
                        }
                        else -> {}
                    }
                }
            }

    override fun getView(): View {
        return arSceneView
    }

    override fun dispose() {
        if (isDisposed) return
        isDisposed = true
        // Destroy AR session
        Log.d(TAG, "dispose called")
        try {
            onPause()
            onDestroy()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    init {

        Log.d(TAG, "Initializing AndroidARView")
        viewContext = context

        arSceneView = ArSceneView(context)
        arSceneView.lightEstimationConfig = LightEstimationConfig.DISABLED

        setupLifeCycle(context)

        sessionManagerChannel.setMethodCallHandler(onSessionMethodCall)
        objectManagerChannel.setMethodCallHandler(onObjectMethodCall)
        anchorManagerChannel.setMethodCallHandler(onAnchorMethodCall)

        //Original visualizer: com.google.ar.sceneform.ux.R.raw.sceneform_footprint

        MaterialFactory.makeTransparentWithColor(context, Color(255f, 255f, 255f, 0.3f))
                .thenAccept { mat ->
                    footprintSelectionVisualizer.footprintRenderable = ShapeFactory.makeCylinder(0.7f,0.05f, Vector3(0f,0f,0f), mat)
                }

        transformationSystem =
                TransformationSystem(
                        activity.resources.displayMetrics,
                        footprintSelectionVisualizer)

        onResume() // call onResume once to setup initial session
        // TODO: find out why this does not happen automatically
    }

    private fun setupLifeCycle(context: Context) {
        activityLifecycleCallbacks =
                object : Application.ActivityLifecycleCallbacks {
                    override fun onActivityCreated(
                            activity: Activity,
                            savedInstanceState: Bundle?
                    ) {
                        Log.d(TAG, "onActivityCreated")
                    }

                    override fun onActivityStarted(activity: Activity) {
                        Log.d(TAG, "onActivityStarted")
                    }

                    override fun onActivityResumed(activity: Activity) {
                        Log.d(TAG, "onActivityResumed")
                        onResume()
                    }

                    override fun onActivityPaused(activity: Activity) {
                        Log.d(TAG, "onActivityPaused")
                        onPause()
                    }

                    override fun onActivityStopped(activity: Activity) {
                        Log.d(TAG, "onActivityStopped")
                        // onStopped()
                        onPause()
                    }

                    override fun onActivitySaveInstanceState(
                            activity: Activity,
                            outState: Bundle
                    ) {}

                    override fun onActivityDestroyed(activity: Activity) {
                        Log.d(TAG, "onActivityDestroyed")
//                        onPause()
//                        onDestroy()
                    }
                }

        activity.application.registerActivityLifecycleCallbacks(this.activityLifecycleCallbacks)
    }

    private fun reportArSessionError(message: String) {
        Toast.makeText(activity, message, Toast.LENGTH_LONG).show()
        sessionManagerChannel.invokeMethod("onError", listOf(message))
    }

    private fun captureFrame(result: MethodChannel.Result, withFrame: Boolean) {
        val width = arSceneView.width
        val height = arSceneView.height
        if (width <= 0 || height <= 0) {
            result.error("CAPTURE_NOT_READY", "La cámara aún no está lista", null)
            return
        }
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val worker = HandlerThread("BioInnovaPhoto").apply { start() }
        PixelCopy.request(arSceneView, bitmap, { copyResult ->
            try {
                if (copyResult != PixelCopy.SUCCESS) {
                    throw IOException("No se pudo capturar la cámara ($copyResult)")
                }
                if (withFrame) drawEventFrame(bitmap)
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                val bytes = stream.toByteArray()
                Handler(viewContext.mainLooper).post { result.success(bytes) }
            } catch (e: Exception) {
                Log.e(TAG, "AR photo capture failed", e)
                Handler(viewContext.mainLooper).post {
                    result.error("CAPTURE_FAILED", e.localizedMessage, null)
                }
            } finally {
                bitmap.recycle()
                worker.quitSafely()
            }
        }, Handler(worker.looper))
    }

    private fun drawEventFrame(photo: Bitmap) {
        val asset = if (photo.width > photo.height) {
            "assets/frames/marco_horizontal.png"
        } else {
            "assets/frames/marco_vertical.png"
        }
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val frame = viewContext.assets.open(key).use { BitmapFactory.decodeStream(it) }
            ?: throw IOException("No se pudo cargar el marco del evento")
        val canvas = Canvas(photo)
        canvas.drawBitmap(
            frame, null, RectF(0f, 0f, photo.width.toFloat(), photo.height.toFloat()),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG),
        )
        frame.recycle()
        val shortSide = minOf(photo.width, photo.height).toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textSize = shortSide * 0.028f
            setShadowLayer(shortSide * 0.012f, 0f, shortSide * 0.003f, Color.rgb(6, 38, 19))
        }
        canvas.drawText("ENCUENTRO REGIONAL AMAZÓNICO", photo.width / 2f, shortSide * 0.07f, paint)
        paint.color = Color.rgb(255, 247, 233)
        canvas.drawText(
            "SAN MARTÍN 2026 · BIOINNOVA", photo.width / 2f,
            photo.height - shortSide * 0.05f, paint,
        )
    }

    private fun savePhoto(bytes: ByteArray): Uri {
        val resolver = viewContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "BioInnova_${System.currentTimeMillis()}.png")
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/BioInnova")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IOException("No se pudo crear la foto en la galería")
        try {
            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: throw IOException("No se pudo escribir la foto")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                resolver.update(uri, ContentValues().apply {
                    put(MediaStore.Images.Media.IS_PENDING, 0)
                }, null, null)
            }
            return uri
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
    }

    fun onResume() {
        // Create session if there is none
        if (arSceneView.session == null) {
            Log.d(TAG, "ARSceneView session is null. Trying to initialize")
            try {
                var session: Session?
                if (ArCoreApk.getInstance().requestInstall(activity, mUserRequestedInstall) ==
                        ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                    Log.d(TAG, "Install of ArCore APK requested")
                    session = null
                } else {
                    session = Session(activity)
                }

                if (session == null) {
                    // Ensures next invocation of requestInstall() will either return
                    // INSTALLED or throw an exception.
                    mUserRequestedInstall = false
                    return
                } else {
                    val config = Config(session)
                    config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
                    config.focusMode = Config.FocusMode.AUTO
                    config.lightEstimationMode = Config.LightEstimationMode.DISABLED
                    config.planeFindingMode = planeFindingMode
                    config.instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
                    session.configure(config)
                    arSceneView.setSession(session)
                }
            } catch (ex: UnavailableUserDeclinedInstallationException) {
                reportArSessionError(
                        "Se canceló la instalación de Servicios de Google Play para RA. " +
                                "Complétala en Google Play y vuelve a iniciar la experiencia.")
                return
            } catch (ex: UnavailableArcoreNotInstalledException) {
                reportArSessionError(
                        "Faltan los Servicios de Google Play para RA. " +
                                "Instálalos y vuelve a iniciar la experiencia.")
                return
            } catch (ex: UnavailableApkTooOldException) {
                reportArSessionError("Actualiza los Servicios de Google Play para RA.")
                return
            } catch (ex: UnavailableSdkTooOldException) {
                reportArSessionError("Esta app necesita actualizarse para usar ARCore.")
                return
            } catch (ex: UnavailableDeviceNotCompatibleException) {
                reportArSessionError(
                        "Este teléfono no es compatible con ARCore. " +
                                "Prueba con un dispositivo de la lista oficial de Google.")
                return
            } catch (e: Exception) {
                reportArSessionError(
                        "No se pudo iniciar ARCore: " +
                                (e.localizedMessage ?: "comprueba la compatibilidad del teléfono."))
                return
            }
        }

        try {
            arSceneView.resume()
        } catch (ex: CameraNotAvailableException) {
            Log.e(TAG, "Camera unavailable while resuming AR", ex)
            reportArSessionError("La cámara está ocupada. Cierra otras apps que la usen y toca Buscar el suelo.")
            return
        } catch (e : Exception){
            Log.e(TAG, "Unable to resume AR", e)
            reportArSessionError("No se pudo abrir la cámara de RA. Toca Buscar el suelo para reintentar.")
            return
        }
    }

    fun onPause() {
        // hide instructions view if no longer required
        if (showAnimatedGuide){
            val view = activity.findViewById(R.id.content) as ViewGroup
            view.removeView(animatedGuide)
            showAnimatedGuide = false
        }
        try {
            arSceneView.pause()
        } catch (e: Exception) {
            Log.w(TAG, "AR session could not pause cleanly", e)
        }
    }

    fun onDestroy() {
        try {
            activeAnimators.values.toList().forEach { it.cancel() }
            activeAnimators.clear()
            appearanceAnimators.values.toList().forEach { it.cancel() }
            appearanceAnimators.clear()
            roamingMovements.values.toList().forEach { it.cancel() }
            roamingMovements.clear()
            orientationTurns.values.toList().forEach { it.cancel() }
            orientationTurns.clear()
            roamingNodes.clear()
            outOfViewSince.clear()
            lastRoamAt.clear()
            arSceneView.session?.close()
            arSceneView.destroy()
            arSceneView.scene?.removeOnUpdateListener(sceneUpdateListener)
            arSceneView.scene?.removeOnPeekTouchListener(onNodeTapListener)
        }catch (e : Exception){
            e.printStackTrace();
        }
    }

    private fun initializeARView(call: MethodCall, result: MethodChannel.Result) {
        // Unpack call arguments
        val argShowFeaturePoints: Boolean? = call.argument<Boolean>("showFeaturePoints")
        val argPlaneDetectionConfig: Int? = call.argument<Int>("planeDetectionConfig")
        val argShowPlanes: Boolean? = call.argument<Boolean>("showPlanes")
        val argCustomPlaneTexturePath: String? = call.argument<String>("customPlaneTexturePath")
        val argShowWorldOrigin: Boolean? = call.argument<Boolean>("showWorldOrigin")
        val argHandleTaps: Boolean? = call.argument<Boolean>("handleTaps")
        val argHandleRotation: Boolean? = call.argument<Boolean>("handleRotation")
        val argHandlePans: Boolean? = call.argument<Boolean>("handlePans")
        val argShowAnimatedGuide: Boolean? = call.argument<Boolean>("showAnimatedGuide")


        if (this::sceneUpdateListener.isInitialized) arSceneView.scene.removeOnUpdateListener(sceneUpdateListener)
        if (this::onNodeTapListener.isInitialized) arSceneView.scene.removeOnPeekTouchListener(onNodeTapListener)
        sceneUpdateListener = com.google.ar.sceneform.Scene.OnUpdateListener {
            frameTime: FrameTime -> onFrame(frameTime)
        }
        onNodeTapListener = com.google.ar.sceneform.Scene.OnPeekTouchListener { hitTestResult, motionEvent ->
            //if (hitTestResult.node != null){
                //transformationSystem.selectionVisualizer.applySelectionVisual(hitTestResult.node as TransformableNode)
                //transformationSystem.selectNode(hitTestResult.node as TransformableNode)
            //}
            if (hitTestResult.node != null && motionEvent?.action == MotionEvent.ACTION_DOWN) {
                objectManagerChannel.invokeMethod("onNodeTap", listOf(hitTestResult.node?.name))
            }
            transformationSystem.onTouch(
                hitTestResult,
                motionEvent
            )
        }

        arSceneView.scene?.addOnUpdateListener(sceneUpdateListener)
        arSceneView.scene?.addOnPeekTouchListener(onNodeTapListener)


        // Flutter supplies the scanning guidance.
        // Configure feature points
        if (argShowFeaturePoints ==
                true) { // explicit comparison necessary because of nullable type
            arSceneView.scene.addChild(pointCloudNode)
            showFeaturePoints = true
        } else {
            showFeaturePoints = false
            while (pointCloudNode.children?.size
                    ?: 0 > 0) {
                pointCloudNode.children?.first()?.setParent(null)
            }
            pointCloudNode.setParent(null)
        }

        // Cache the requested plane mode because ARCore may still be installing.
        planeFindingMode = when (argPlaneDetectionConfig) {
            1 -> Config.PlaneFindingMode.HORIZONTAL
            2 -> Config.PlaneFindingMode.VERTICAL
            3 -> Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
            else -> Config.PlaneFindingMode.DISABLED
        }
        arSceneView.session?.let { session ->
            session.config?.let { config ->
                config.planeFindingMode = planeFindingMode
                config.instantPlacementMode = Config.InstantPlacementMode.LOCAL_Y_UP
                session.configure(config)
            }
        }

        // Configure whether or not detected planes should be shown
        arSceneView.planeRenderer.isVisible = if (argShowPlanes == true) true else false
        // Create custom plane renderer (use supplied texture & increase radius)
        argCustomPlaneTexturePath?.let {
            val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
            val key: String = loader.getLookupKeyForAsset(it)

            val sampler =
                    Texture.Sampler.builder()
                            .setMinFilter(Texture.Sampler.MinFilter.LINEAR)
                            .setWrapMode(Texture.Sampler.WrapMode.REPEAT)
                            .build()
            Texture.builder()
                    .setSource(viewContext, Uri.parse(key))
                    .setSampler(sampler)
                    .build()
                    .thenAccept { texture: Texture? ->
                        arSceneView.planeRenderer.material.thenAccept { material: Material ->
                            material.setTexture(PlaneRenderer.MATERIAL_TEXTURE, texture)
                            material.setFloat(PlaneRenderer.MATERIAL_SPOTLIGHT_RADIUS, 10f)
                        }
                    }
            // Set radius to render planes in
            arSceneView.scene.addOnUpdateListener { frameTime: FrameTime? ->
                val planeRenderer = arSceneView.planeRenderer
                planeRenderer.material.thenAccept { material: Material ->
                    material.setFloat(
                            PlaneRenderer.MATERIAL_SPOTLIGHT_RADIUS,
                            10f) // Sets the radius in which to visualize planes
                }
            }
        }

        // Configure world origin
        if (argShowWorldOrigin == true) {
            worldOriginNode = modelBuilder.makeWorldOriginNode(viewContext)
            arSceneView.scene.addChild(worldOriginNode)
        } else {
            worldOriginNode.setParent(null)
        }

        // Configure Tap handling
        if (argHandleTaps == true) { // explicit comparison necessary because of nullable type
            arSceneView.scene.setOnTouchListener{ hitTestResult: HitTestResult, motionEvent: MotionEvent? -> onTap(hitTestResult, motionEvent) }
        }

        // Configure gestures
        if (argHandleRotation ==
                true) { // explicit comparison necessary because of nullable type
            enableRotation = true
        } else {
            enableRotation = false
        }
        if (argHandlePans ==
                true) { // explicit comparison necessary because of nullable type
            enablePans = true
        } else {
            enablePans = false
        }

        result.success(null)
    }

    private fun onFrame(frameTime: FrameTime) {
        // hide instructions view if no longer required
        if (showAnimatedGuide && arSceneView.arFrame != null){
            for (plane in arSceneView.arFrame!!.getUpdatedTrackables(Plane::class.java)) {
                if (plane.trackingState === TrackingState.TRACKING) {
                    val view = activity.findViewById(R.id.content) as ViewGroup
                    view.removeView(animatedGuide)
                    showAnimatedGuide = false
                    break
                }
            }
        }

        if (showFeaturePoints) {
            // remove points from last frame
            while (pointCloudNode.children?.size
                    ?: 0 > 0) {
                pointCloudNode.children?.first()?.setParent(null)
            }
            var pointCloud = arSceneView.arFrame?.acquirePointCloud()
            // Access point cloud data (returns FloatBufferw with x,y,z coordinates and confidence
            // value).
            val points = pointCloud?.getPoints() ?: FloatBuffer.allocate(0)
            // Check if there are any feature points
            if (points.limit() / 4 >= 1) {
                for (index in 0 until points.limit() / 4) {
                    // Add feature point to scene
                    val featurePoint =
                            modelBuilder.makeFeaturePointNode(
                                    viewContext,
                                    points.get(4 * index),
                                    points.get(4 * index + 1),
                                    points.get(4 * index + 2))
                    featurePoint.setParent(pointCloudNode)
                }
            }
            // Release resources
            pointCloud?.release()
        }
        val updatedAnchors = arSceneView.arFrame!!.updatedAnchors
        // Notify the cloudManager of all the updates.
        if (this::cloudAnchorHandler.isInitialized) {cloudAnchorHandler.onUpdate(updatedAnchors)}

        if (keepNodeSelected && transformationSystem.selectedNode != null && transformationSystem.selectedNode!!.isTransforming){
            // If the selected node is currently transforming, we want to deselect it as soon as the transformation is done
            keepNodeSelected = false
        }
        if (!keepNodeSelected && transformationSystem.selectedNode != null && !transformationSystem.selectedNode!!.isTransforming){
            // once the transformation is done, deselect the node and allow selection of another node
            transformationSystem.selectNode(null)
            keepNodeSelected = true
        }
        if (!enablePans && !enableRotation){
            //unselect all nodes as we do not want the selection visualizer
            transformationSystem.selectNode(null)
        }

        updateRoamingCharacters()

    }

    private fun updateRoamingCharacters() {
        if (roamingNodes.isEmpty() || arSceneView.width <= 0 || arSceneView.height <= 0) return
        val now = SystemClock.elapsedRealtime()
        for (name in roamingNodes.toList()) {
            if (roamingMovements.containsKey(name)) continue
            val node = arSceneView.scene.findByName(name) ?: continue
            val camera = arSceneView.scene.camera
            val localPosition = camera.worldToLocalPoint(node.worldPosition)
            val screenPosition = camera.worldToScreenPoint(node.worldPosition)
            val visible = localPosition.z < 0f &&
                screenPosition.x >= 0f && screenPosition.x <= arSceneView.width &&
                screenPosition.y >= 0f && screenPosition.y <= arSceneView.height
            if (visible) {
                outOfViewSince.remove(name)
                continue
            }

            val hiddenSince = outOfViewSince.getOrPut(name) { now }
            val lastMove = lastRoamAt[name] ?: Long.MIN_VALUE
            if (now - hiddenSince >= 900L && now - lastMove >= 2500L) {
                startRoamingMovement(name, node)
                lastRoamAt[name] = now
            }
        }
    }

    private fun startRoamingMovement(name: String, node: Node) {
        val start = Vector3(node.localPosition.x, node.localPosition.y, node.localPosition.z)
        val cameraLocal = arSceneView.scene.camera.worldToLocalPoint(node.worldPosition)
        val isOutsideView = cameraLocal.z >= 0f ||
            arSceneView.scene.camera.worldToScreenPoint(node.worldPosition).let {
                it.x < 0f || it.x > arSceneView.width || it.y < 0f || it.y > arSceneView.height
            }
        if (!isOutsideView) return
        val camera = arSceneView.scene.camera
        val forward = camera.forward
        val cameraWorld = camera.worldPosition
        val targetWorld = Vector3(
            cameraWorld.x + forward.x * 1.35f,
            node.worldPosition.y,
            cameraWorld.z + forward.z * 1.35f,
        )
        animateCharacterTo(name, node, targetWorld)
    }

    private fun animateCharacterTo(name: String, node: Node, targetWorld: Vector3): Boolean {
        roamingMovements.remove(name)?.cancel()
        orientationTurns.remove(name)?.cancel()
        val start = Vector3(node.localPosition.x, node.localPosition.y, node.localPosition.z)
        val target = (node.parent as? Node)?.worldToLocalPoint(targetWorld) ?: targetWorld
        val dx = target.x - start.x
        val dz = target.z - start.z
        val distance = kotlin.math.sqrt(dx * dx + dz * dz)
        if (distance < 0.15f) return false
        val end = Vector3(target.x, start.y, target.z)
        val travelYaw = Math.toDegrees(atan2(dx.toDouble(), dz.toDouble())).toFloat()
        val startRotation = node.localRotation
        val travelRotation = com.google.ar.sceneform.math.Quaternion.axisAngle(
            Vector3(0f, 1f, 0f), travelYaw,
        )
        val movement = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = (distance / 0.75f * 1000f).toLong().coerceIn(900L, 6500L)
            addUpdateListener { value ->
                val progress = value.animatedValue as Float
                node.localPosition = Vector3(
                    start.x + (end.x - start.x) * progress,
                    start.y + (end.y - start.y) * progress,
                    start.z + (end.z - start.z) * progress,
                )
                node.localRotation = com.google.ar.sceneform.math.Quaternion.slerp(
                    startRotation, travelRotation, (progress * 4f).coerceIn(0f, 1f),
                )
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (roamingMovements[name] !== this@apply) return
                    roamingMovements.remove(name)
                    if (arSceneView.scene.findByName(name) != null) {
                        turnCharacterTowardCamera(name, node)
                        activeAnimators[name]?.cancel()
                        playAnimationContaining(name, listOf("wave", "talk"), loop = false)
                        outOfViewSince.remove(name)
                    }
                }
            })
        }
        roamingMovements[name] = movement
        if (distance < 1.2f || !playAnimationContaining(name, listOf("running", "run"), loop = true)) {
            playAnimationContaining(name, listOf("walking", "walk"), loop = true)
        }
        movement.start()
        return true
    }

    private fun turnCharacterTowardCamera(name: String, node: Node) {
        val cameraWorld = arSceneView.scene.camera.worldPosition
        val cameraLocal = (node.parent as? Node)?.worldToLocalPoint(cameraWorld) ?: cameraWorld
        val dx = cameraLocal.x - node.localPosition.x
        val dz = cameraLocal.z - node.localPosition.z
        if (dx * dx + dz * dz < 0.01f) return
        val yaw = Math.toDegrees(atan2(dx.toDouble(), dz.toDouble())).toFloat()
        val targetRotation = com.google.ar.sceneform.math.Quaternion.axisAngle(
            Vector3(0f, 1f, 0f), yaw,
        )
        val startRotation = node.localRotation
        val turn = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 420L
            addUpdateListener { value ->
                node.localRotation = com.google.ar.sceneform.math.Quaternion.slerp(
                    startRotation, targetRotation, value.animatedValue as Float,
                )
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    if (orientationTurns[name] === this@apply) orientationTurns.remove(name)
                }
            })
        }
        orientationTurns[name] = turn
        turn.start()
    }

    private fun findModelRenderable(name: String): RenderableInstance? =
        arSceneView.scene.findByName(name)?.renderableInstance

    private fun playAnimationContaining(nodeName: String, terms: List<String>, loop: Boolean): Boolean {
        val renderable = findModelRenderable(nodeName) ?: return false
        val keywords = terms.map { it.lowercase() }
        val clip = (0 until renderable.animationCount)
            .map { renderable.getAnimation(it) }
            .firstOrNull { animation -> keywords.any { animation.name.lowercase().contains(it) } }
            ?: return false
        return playCharacterAnimation(nodeName, clip.name, loop)
    }

    private fun playCharacterAnimation(nodeName: String, animationName: String, loop: Boolean): Boolean {
        if (roamingMovements.containsKey(nodeName) &&
            !animationName.contains("run", ignoreCase = true) &&
            !animationName.contains("walk", ignoreCase = true)) return false
        val renderable = findModelRenderable(nodeName) ?: return false
        val clip = (0 until renderable.animationCount)
            .map { renderable.getAnimation(it) }
            .firstOrNull { it.name == animationName } ?: return false
        return try {
            activeAnimators.remove(nodeName)?.cancel()
            val animator = ModelAnimator.ofAnimation(renderable, clip.name).apply {
                repeatCount = if (loop) ValueAnimator.INFINITE else 0
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        if (activeAnimators[nodeName] === this@apply) {
                            activeAnimators.remove(nodeName)
                        }
                    }
                })
            }
            activeAnimators[nodeName] = animator
            animator.start()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Unable to play animation $animationName", e)
            false
        }
    }

    private fun stopCharacterAnimation(nodeName: String) {
        activeAnimators.remove(nodeName)?.cancel()
    }

    private fun addNode(dict_node: HashMap<String, Any>, dict_anchor: HashMap<String, Any>? = null): CompletableFuture<Boolean>{
        val completableFutureSuccess: CompletableFuture<Boolean> = CompletableFuture()

        try {
            when (dict_node["type"] as Int) {
                0 -> { // GLTF2 Model from Flutter asset folder
                    // Get path to given Flutter asset
                    val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
                    val key: String = loader.getLookupKeyForAsset(dict_node["uri"] as String)

                    // Add object to scene
                    modelBuilder.makeNodeFromGltf(viewContext, transformationSystem, objectManagerChannel, enablePans, enableRotation, dict_node["name"] as String, key, dict_node["transformation"] as ArrayList<Double>)
                            .thenAccept{node ->
                                val anchorName: String? = dict_anchor?.get("name") as? String
                                val anchorType: Int? = dict_anchor?.get("type") as? Int
                                if (anchorName != null && anchorType != null) {
                                    val anchorNode = arSceneView.scene.findByName(anchorName) as AnchorNode?
                                    if (anchorNode != null) {
                                        anchorNode.addChild(node)
                                        completableFutureSuccess.complete(true)
                                    } else {
                                        completableFutureSuccess.complete(false)
                                    }
                                } else {
                                    arSceneView.scene.addChild(node)
                                    completableFutureSuccess.complete(true)
                                }
                                completableFutureSuccess.complete(false)
                            }
                            .exceptionally { throwable ->
                                // Pass error to session manager (this has to be done on the main thread if this activity)
                                val mainHandler = Handler(viewContext.mainLooper)
                                val runnable = Runnable {sessionManagerChannel.invokeMethod("onError", listOf("Unable to load renderable" +  dict_node["uri"] as String)) }
                                mainHandler.post(runnable)
                                completableFutureSuccess.completeExceptionally(throwable)
                                null // return null because java expects void return (in java, void has no instance, whereas in Kotlin, this closure returns a Unit which has one instance)
                            }
                }
                1 -> { // GLB Model from the web
                    modelBuilder.makeNodeFromGlb(viewContext, transformationSystem, objectManagerChannel, enablePans, enableRotation, dict_node["name"] as String, dict_node["uri"] as String, dict_node["transformation"] as ArrayList<Double>)
                            .thenAccept{node ->
                                val anchorName: String? = dict_anchor?.get("name") as? String
                                val anchorType: Int? = dict_anchor?.get("type") as? Int
                                if (anchorName != null && anchorType != null) {
                                    val anchorNode = arSceneView.scene.findByName(anchorName) as AnchorNode?
                                    if (anchorNode != null) {
                                        anchorNode.addChild(node)
                                        completableFutureSuccess.complete(true)
                                    } else {
                                        completableFutureSuccess.complete(false)
                                    }
                                } else {
                                    arSceneView.scene.addChild(node)
                                    completableFutureSuccess.complete(true)
                                }
                                completableFutureSuccess.complete(false)
                            }
                            .exceptionally { throwable ->
                                // Pass error to session manager (this has to be done on the main thread if this activity)
                                val mainHandler = Handler(viewContext.mainLooper)
                                val runnable = Runnable {sessionManagerChannel.invokeMethod("onError", listOf("Unable to load renderable" +  dict_node["uri"] as String)) }
                                mainHandler.post(runnable)
                                completableFutureSuccess.completeExceptionally(throwable)
                                null // return null because java expects void return (in java, void has no instance, whereas in Kotlin, this closure returns a Unit which has one instance)
                            }
                }
                2 -> { // fileSystemAppFolderGLB
                    val documentsPath = viewContext.getApplicationInfo().dataDir
                    val assetPath = documentsPath + "/app_flutter/" + dict_node["uri"] as String

                    modelBuilder.makeNodeFromGlb(viewContext, transformationSystem, objectManagerChannel, enablePans, enableRotation, dict_node["name"] as String, assetPath as String, dict_node["transformation"] as ArrayList<Double>) //
                            .thenAccept{node ->
                                val anchorName: String? = dict_anchor?.get("name") as? String
                                val anchorType: Int? = dict_anchor?.get("type") as? Int
                                if (anchorName != null && anchorType != null) {
                                    val anchorNode = arSceneView.scene.findByName(anchorName) as AnchorNode?
                                    if (anchorNode != null) {
                                        anchorNode.addChild(node)
                                        completableFutureSuccess.complete(true)
                                    } else {
                                        completableFutureSuccess.complete(false)
                                    }
                                } else {
                                    arSceneView.scene.addChild(node)
                                    completableFutureSuccess.complete(true)
                                }
                                completableFutureSuccess.complete(false)
                            }
                            .exceptionally { throwable ->
                                // Pass error to session manager (this has to be done on the main thread if this activity)
                                val mainHandler = Handler(viewContext.mainLooper)
                                val runnable = Runnable {sessionManagerChannel.invokeMethod("onError", listOf("Unable to load renderable " +  dict_node["uri"] as String)) }
                                mainHandler.post(runnable)
                                completableFutureSuccess.completeExceptionally(throwable)
                                null // return null because java expects void return (in java, void has no instance, whereas in Kotlin, this closure returns a Unit which has one instance)
                            }
                }
                3 -> { //fileSystemAppFolderGLTF2
                    // Get path to given Flutter asset
                    val documentsPath = viewContext.getApplicationInfo().dataDir
                    val assetPath = documentsPath + "/app_flutter/" + dict_node["uri"] as String

                    // Add object to scene
                    modelBuilder.makeNodeFromGltf(viewContext, transformationSystem, objectManagerChannel, enablePans, enableRotation, dict_node["name"] as String, assetPath, dict_node["transformation"] as ArrayList<Double>)
                            .thenAccept{node ->
                                val anchorName: String? = dict_anchor?.get("name") as? String
                                val anchorType: Int? = dict_anchor?.get("type") as? Int
                                if (anchorName != null && anchorType != null) {
                                    val anchorNode = arSceneView.scene.findByName(anchorName) as AnchorNode?
                                    if (anchorNode != null) {
                                        anchorNode.addChild(node)
                                        completableFutureSuccess.complete(true)
                                    } else {
                                        completableFutureSuccess.complete(false)
                                    }
                                } else {
                                    arSceneView.scene.addChild(node)
                                    completableFutureSuccess.complete(true)
                                }
                                completableFutureSuccess.complete(false)
                            }
                            .exceptionally { throwable ->
                                // Pass error to session manager (this has to be done on the main thread if this activity)
                                val mainHandler = Handler(viewContext.mainLooper)
                                val runnable = Runnable {sessionManagerChannel.invokeMethod("onError", listOf("Unable to load renderable" +  dict_node["uri"] as String)) }
                                mainHandler.post(runnable)
                                completableFutureSuccess.completeExceptionally(throwable)
                                null // return null because java expects void return (in java, void has no instance, whereas in Kotlin, this closure returns a Unit which has one instance)
                            }
                }
                4 -> { // GLB model bundled as a Flutter asset
                    val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
                    val key = loader.getLookupKeyForAsset(dict_node["uri"] as String)
                    modelBuilder.makeNodeFromGlb(
                        viewContext,
                        transformationSystem,
                        objectManagerChannel,
                        enablePans,
                        enableRotation,
                        dict_node["name"] as String,
                        key,
                        dict_node["transformation"] as ArrayList<Double>,
                    ).thenAccept { node ->
                        Log.i(TAG, "GLB clips: ${node.renderableInstance?.animationCount ?: 0}")
                        val anchorName = dict_anchor?.get("name") as? String
                        if (anchorName != null) {
                            val anchorNode = arSceneView.scene.findByName(anchorName) as? AnchorNode
                            if (anchorNode != null) {
                                // Keep the mascot visible when ARCore temporarily loses
                                // tracking of the plane anchor during a camera turn.
                                arSceneView.scene.addChild(node)
                                node.worldPosition = anchorNode.worldPosition
                                animateAppearance(node)
                                completableFutureSuccess.complete(true)
                            } else {
                                completableFutureSuccess.complete(false)
                            }
                        } else {
                            arSceneView.scene.addChild(node)
                            animateAppearance(node)
                            completableFutureSuccess.complete(true)
                        }
                    }.exceptionally { throwable ->
                        val mainHandler = Handler(viewContext.mainLooper)
                        mainHandler.post {
                            sessionManagerChannel.invokeMethod(
                                "onError",
                                listOf("Unable to load renderable ${dict_node["uri"]}"),
                            )
                        }
                        completableFutureSuccess.completeExceptionally(throwable)
                        null
                    }
                }
                else -> {
                    completableFutureSuccess.complete(false)
                }
            }
        } catch (e: java.lang.Exception) {
            completableFutureSuccess.completeExceptionally(e)
        }

        return completableFutureSuccess
    }

    private fun animateAppearance(node: Node) {
        val fullScale = Vector3(node.localScale.x, node.localScale.y, node.localScale.z)
        val finalPosition = Vector3(node.localPosition.x, node.localPosition.y, node.localPosition.z)
        node.localScale = Vector3(0.001f, 0.001f, 0.001f)
        node.localPosition = Vector3(finalPosition.x, finalPosition.y - 0.12f, finalPosition.z)
        Handler(viewContext.mainLooper).postDelayed({
            if (node.parent == null) return@postDelayed
            val animator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 850L
                addUpdateListener { value ->
                    val t = value.animatedValue as Float
                    val ease = 1f - (1f - t) * (1f - t) * (1f - t)
                    node.localScale = Vector3(
                        fullScale.x * ease, fullScale.y * ease, fullScale.z * ease,
                    )
                    node.localPosition = Vector3(
                        finalPosition.x, finalPosition.y - 0.12f * (1f - ease), finalPosition.z,
                    )
                }
                addListener(object : AnimatorListenerAdapter() {
                    override fun onAnimationEnd(animation: Animator) {
                        appearanceAnimators.remove(node.name)
                    }
                })
            }
            appearanceAnimators[node.name] = animator
            animator.start()
        }, 150L)
    }

    private fun transformNode(name: String, transform: ArrayList<Double>) {
        val node = arSceneView.scene.findByName(name)
        node?.let {
            val transformTriple = deserializeMatrix4(transform)
            // Preserve the size normalized from the loaded model bounds.
            it.localPosition = transformTriple.second
            it.localRotation = transformTriple.third
            //it.worldScale = transformTriple.first
            //it.worldPosition = transformTriple.second
            //it.worldRotation = transformTriple.third
        }
    }

    private fun onTap(hitTestResult: HitTestResult, motionEvent: MotionEvent?): Boolean {
        val frame = arSceneView.arFrame
        if (hitTestResult.node != null && motionEvent?.action == MotionEvent.ACTION_DOWN) {
            objectManagerChannel.invokeMethod("onNodeTap", listOf(hitTestResult.node?.name))
            return true
        }
        if (motionEvent != null && motionEvent.action == MotionEvent.ACTION_DOWN) {
            if (transformationSystem.selectedNode == null || (!enablePans && !enableRotation)){
                val allHitResults = frame?.hitTest(motionEvent) ?: listOf<HitResult>()
                val planeAndPointHitResults = allHitResults.filter {
                    val plane = it.trackable as? Plane
                    plane != null &&
                        plane.type == Plane.Type.HORIZONTAL_UPWARD_FACING &&
                        plane.isPoseInPolygon(it.hitPose)
                }
                val placementHits = if (planeAndPointHitResults.isNotEmpty()) {
                    planeAndPointHitResults
                } else if (frame?.camera?.trackingState == TrackingState.TRACKING &&
                    arSceneView.scene.camera.forward.y < -0.12f) {
                    frame.hitTestInstantPlacement(motionEvent.x, motionEvent.y, 1.5f)
                } else {
                    emptyList()
                }
                val serializedPlaneAndPointHitResults: ArrayList<HashMap<String, Any>> =
                    ArrayList(placementHits.map { serializeHitResult(it) })
                sessionManagerChannel.invokeMethod(
                    "onPlaneOrPointTap",
                    serializedPlaneAndPointHitResults
                )
                return true
            } else {
                return false
            }

        }
        return false
    }

    private fun addPlaneAnchor(transform: ArrayList<Double>, name: String): Boolean {
        return try {
            val position = floatArrayOf(deserializeMatrix4(transform).second.x, deserializeMatrix4(transform).second.y, deserializeMatrix4(transform).second.z)
            val rotation = floatArrayOf(deserializeMatrix4(transform).third.x, deserializeMatrix4(transform).third.y, deserializeMatrix4(transform).third.z, deserializeMatrix4(transform).third.w)
            val anchor: Anchor = arSceneView.session!!.createAnchor(Pose(position, rotation))
            val anchorNode = AnchorNode(anchor)
            anchorNode.name = name
            anchorNode.setParent(arSceneView.scene)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun removeAnchor(name: String) {
        val anchorNode = arSceneView.scene.findByName(name) as AnchorNode?
        anchorNode?.let{
            // Remove corresponding anchor from tracking
            anchorNode.anchor?.detach()
            // Remove children
            for (node in anchorNode.children) {
                if (transformationSystem.selectedNode?.name == node.name){
                    transformationSystem.selectNode(null)
                    keepNodeSelected = true
                }
                node.setParent(null)
            }
            // Remove anchor node
            anchorNode.setParent(null)
        }
    }

    private inner class cloudAnchorUploadedListener: CloudAnchorHandler.CloudAnchorListener {
        override fun onCloudTaskComplete(anchorName: String?, anchor: Anchor?) {
            val cloudState = anchor!!.cloudAnchorState
            if (cloudState.isError) {
                Log.e(TAG, "Error uploading anchor, state $cloudState")
                sessionManagerChannel.invokeMethod("onError", listOf("Error uploading anchor, state $cloudState"))
                return
            }
            // Swap old an new anchor of the respective AnchorNode
            val anchorNode = arSceneView.scene.findByName(anchorName) as AnchorNode?
            val oldAnchor = anchorNode?.anchor
            anchorNode?.anchor = anchor
            oldAnchor?.detach()

            val args = HashMap<String, String?>()
            args["name"] = anchorName
            args["cloudanchorid"] = anchor.cloudAnchorId
            anchorManagerChannel.invokeMethod("onCloudAnchorUploaded", args)
        }
    }

    private inner class cloudAnchorDownloadedListener: CloudAnchorHandler.CloudAnchorListener {
        override fun onCloudTaskComplete(anchorName: String?, anchor: Anchor?) {
            val cloudState = anchor!!.cloudAnchorState
            if (cloudState.isError) {
                Log.e(TAG, "Error downloading anchor, state $cloudState")
                sessionManagerChannel.invokeMethod("onError", listOf("Error downloading anchor, state $cloudState"))
                return
            }
            //Log.d(TAG, "---------------- RESOLVING SUCCESSFUL ------------------")
            val newAnchorNode = AnchorNode(anchor)
            // Register new anchor on the Flutter side of the plugin
            anchorManagerChannel.invokeMethod("onAnchorDownloadSuccess", serializeAnchor(newAnchorNode, anchor), object: MethodChannel.Result {
                override fun success(result: Any?) {
                    newAnchorNode.name = result.toString()
                    newAnchorNode.setParent(arSceneView.scene)
                    //Log.d(TAG, "---------------- REGISTERING ANCHOR SUCCESSFUL ------------------")
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    sessionManagerChannel.invokeMethod("onError", listOf("Error while registering downloaded anchor at the AR Flutter plugin: $errorMessage"))
                }

                override fun notImplemented() {
                    sessionManagerChannel.invokeMethod("onError", listOf("Error while registering downloaded anchor at the AR Flutter plugin"))
                }
            })
        }
    }

}


