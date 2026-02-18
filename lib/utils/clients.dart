import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';

class CustomHttpClient extends IOClient {
  CustomHttpClient() : super(_createHttpClient());

  static HttpClient _createHttpClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true; // Allow self-signed certs if any
    client.maxConnectionsPerHost = 5;
    return client;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
     // The IOClient will handle the redirects automatically.
    return super.send(request);
  }
}
