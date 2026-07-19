import 'dart:io';

import 'package:flutter_application_1/services/api_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tempDirectory;
  late File audioFile;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('voice_test_');
    audioFile = File('${tempDirectory.path}/voice.m4a');
    await audioFile.writeAsBytes([1, 2, 3, 4]);
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('uploads audio as multipart and returns transcript', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/chat/transcribe');
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers['content-type'], contains('multipart/form-data'));
      return http.Response('{"text":"phone under 50000"}', 200);
    });
    final service = ChatService(
      httpClient: client,
      tokenProvider: () async => 'test-token',
    );

    final transcript = await service.transcribeAudio(audioFile.path);

    expect(transcript, 'phone under 50000');
  });

  test('surfaces backend transcription error', () async {
    final client = MockClient(
      (_) async => http.Response('{"detail":"No speech was detected."}', 502),
    );
    final service = ChatService(
      httpClient: client,
      tokenProvider: () async => null,
    );

    expect(
      () => service.transcribeAudio(audioFile.path),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'No speech was detected.',
        ),
      ),
    );
  });

  test('uploads a browser Opus/WebM blob as multipart', () async {
    final methods = <String>[];
    final client = MockClient((request) async {
      methods.add(request.method);
      if (request.method == 'GET') {
        expect(request.url.scheme, 'blob');
        return http.Response.bytes([5, 6, 7, 8], 200);
      }
      expect(request.url.path, '/chat/transcribe');
      expect(request.headers['content-type'], contains('multipart/form-data'));
      return http.Response('{"text":"mujhe basic laptop chahiye"}', 200);
    });
    final service = ChatService(
      httpClient: client,
      tokenProvider: () async => null,
    );

    final transcript = await service.transcribeAudio(
      'blob:https://example.test/voice-recording',
      uploadFilename: 'voice.webm',
    );

    expect(transcript, 'mujhe basic laptop chahiye');
    expect(methods, ['GET', 'POST']);
  });
}
