import 'dart:io';

import 'package:flutter_video_info/flutter_video_info.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// アプリからファイルを保存するディレクトリのパス
Future<String> getLocalPath() async {
  Directory tmpDocDir = await getTemporaryDirectory();
  // ignore: avoid_print
  print(tmpDocDir.path);
  return tmpDocDir.path;
}

// ビデオのメタデータ取得
Future<Map<String, dynamic>?> getVideoMetadata(String videoFilePath) async {
  final videoInfo = await FlutterVideoInfo().getVideoInfo(videoFilePath) as VideoData;
  // 縦長画像対応
  if ((videoInfo.orientation! ~/ 90) % 2 == 1) {
    return {
      'width': videoInfo.height,
      'height': videoInfo.width,
      'fps': videoInfo.framerate,
    };
  } else {
    return {
      'width': videoInfo.width,
      'height': videoInfo.height,
      'fps': videoInfo.framerate,
    };
  }
}

// 生成される画像や動画のファイルのキャッシュを削除する
Future<void> removeFFmpegFiles() async {
  final localDirectory = await getTemporaryDirectory();
  for (var entry in localDirectory.listSync(recursive: true, followLinks: false)) {
    final fileName = entry.path.split('/').last;
    if (fileName.startsWith(CommonValue.filePrefix)) {
      entry.deleteSync();
    }
  }
}

// ファイルをカメラロールに保存する
Future<void> saveToCameraRoll(String filePath) async {
  Permission.storage.request();
  await ImageGallerySaver.saveFile(filePath);
}

// アプリを通じて使うの固定の値
class CommonValue {
  // 生成されるキャッシュファイルの名前の頭につける文字列
  static String filePrefix = 'ffmpeg_';
}
