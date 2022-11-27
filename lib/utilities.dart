import 'dart:io';
import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// アプリからファイルを保存するディレクトリのパス
Future<String> localFilePath() async {
  Directory tmpDocDir = await getTemporaryDirectory();
  // ignore: avoid_print
  print(tmpDocDir.path);
  return tmpDocDir.path;
}

// ビデオのメタデータ取得
Future<Map<String, dynamic>?> getVideoMetadata(String videoFilePath) async {
  final videoInfo = await FlutterVideoInfo().getVideoInfo(videoFilePath) as VideoData;
  return {
    'width': videoInfo.width,
    'height': videoInfo.height,
    'fps': videoInfo.framerate,
  };
}

Future<void> removeFiles() async {
  final localDirectory = await getTemporaryDirectory();
  for (var entry in localDirectory.listSync(recursive: true, followLinks: false)) {
    final fileName = entry.path.split('/').last;
    if (fileName.startsWith('ffmpeg_')) {
      entry.deleteSync();
    }
  }
}

Future<void> saveToCameraRoll(String filePath) async {
  Permission.storage.request();
  await ImageGallerySaver.saveFile(filePath);
}
