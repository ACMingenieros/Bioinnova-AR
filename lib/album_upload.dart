import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _url = String.fromEnvironment(
  'BIOINNOVA_ALBUM_UPLOAD_URL',
  defaultValue: 'https://bioinnova.acmingenieros.com/api/upload.php',
);

Future<void> uploadPhotoToAlbum(Uint8List bytes) async {
  try {
    await _sendPhoto(bytes);
  } on SocketException catch (error) {
    if (!error.message.toLowerCase().contains('host lookup')) rethrow;
    for (final address in const ['104.21.59.103', '172.67.223.9']) {
      try {
        await _sendPhoto(bytes, fallbackAddress: address);
        return;
      } on SocketException {
        // Try the second edge if the first is unavailable on this network.
      }
    }
    rethrow;
  }
}

Future<void> _sendPhoto(Uint8List bytes, {String? fallbackAddress}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
  if (fallbackAddress != null) {
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) async {
      final socket = Socket.connect(
        InternetAddress(fallbackAddress),
        uri.port,
        timeout: const Duration(seconds: 8),
      ).then((socket) => SecureSocket.secure(socket, host: uri.host));
      return ConnectionTask.fromSocket<Socket>(socket, () {});
    };
  }
  try {
    final request = await client.postUrl(Uri.parse(_url));
    request.headers.contentType = ContentType('image', 'png');
    request.contentLength = bytes.length;
    request.add(bytes);
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.created) {
      final message = jsonDecode(body);
      throw HttpException(
        message is Map ? (message['error']?.toString() ?? body) : body,
        uri: Uri.parse(_url),
      );
    }
  } finally {
    client.close(force: true);
  }
}
