import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

// A custom AudioSource that plays audio from a list of bytes in memory.
// This is necessary for handling streams from sources like YouTube where URLs are temporary.
class MyBytesAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  final String contentType;

  MyBytesAudioSource(this._buffer,
      {required this.contentType, required dynamic tag})
      : super(tag: tag);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;

    // Return a stream of the requested byte range.
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: contentType, // Use the dynamic content type
    );
  }
}
