# Bioinnova-AR

Aplicación Android en Flutter que coloca un tigrillo animado en el suelo mediante realidad aumentada.

## Stack

- Flutter y Dart para la interfaz y el flujo móvil.
- ARCore 1.56.0 a través del plugin local `packages/ar_flutter_plugin` para cámara, detección de planos horizontales y anclaje del personaje.
- Modelo GLB integrado en `assets/models/tigrillo.glb`, con texturas y clips de animación.
- `flutter_tts` para narración en español latinoamericano usando el motor disponible en el teléfono.
- Android Gradle Plugin y Gradle Wrapper para producir el APK.

La app requiere un Android compatible con ARCore y Google Play Services for AR. Android la declara como **AR Required** para que Google Play filtre equipos compatibles y prepare el servicio de RA al instalarla. En el evento, el visitante debe escanear un QR, instalar el APK si todavía no está instalado y abrir la app; luego acepta el permiso de cámara, apunta al piso y toca el plano detectado para colocar al tigrillo. El APK actual no incluye Android App Links; un QR que abra directamente la app requiere una página pública y enlaces verificados configurados para su dominio.

El modelo conserva la malla, textura y animaciones originales. Para verlo a buen tamaño, toca una superficie libre a unos 1–1,5 m. Al colocarlo, comienza el guion de bienvenida; los controles permiten avanzar, repetir y volver a ubicar al personaje.

## Artefactos

- APK de lanzamiento: `build/app/outputs/flutter-apk/app-release.apk`.
- Modelo incluido: `assets/models/tigrillo.glb`.
- Vista previa del modelo: `assets/models/preview_tigrillo.png`.

El APK actual está firmado con la configuración `debug` declarada en `android/app/build.gradle.kts`. Sirve para instalación y demostración; para distribuirlo de forma mantenible entre eventos, configura una clave de firma de lanzamiento y aumenta el número de versión.

## QR para el evento

Publica el APK en un alojamiento HTTPS y prepara una página HTTPS con:

1. Descripción de la experiencia y requisitos de ARCore.
2. Botón de descarga del APK.
3. Instrucción breve: instalar, abrir, permitir cámara, apuntar al suelo y tocar.

La landing está en una carpeta hermana de este proyecto (`../pagina`) y se publica por separado en `https://bioinnova.acmingenieros.com`. El QR del evento debe apuntar a esa URL, no al archivo APK.

## Compilar

Con Flutter y Android SDK configurados:

```powershell
flutter pub get
flutter build apk --release
```

La experiencia de cámara requiere un teléfono Android compatible; la vista de AR no se puede validar en los targets web/desktop de Flutter.
