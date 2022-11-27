import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/landmark_painter.dart';
import 'package:flutter_mlkit_video/utilities.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class MlkitVideoConverter {
  MlkitVideoConverter({required this.localPath});

  late final int videoWidth;
  late final int videoHeight;
  late final double videoFps;
  late final String videoFilePath;
  final String localPath;

  // メタデータ取得
  Future<void> initialize({required String videoFilePath}) async {
    final Map<String, dynamic>? videoInfo = await getVideoMetadata(videoFilePath);
    videoWidth = videoInfo!['width'];
    videoHeight = videoInfo['height'];
    videoFps = videoInfo['fps'];
    this.videoFilePath = videoFilePath;
  }

  Future<List<File>?> convertVideoToFrames({required BuildContext context}) async {
    const exportPrefix = 'ffmpeg_';

    await removeFiles();

    // フレーム抽出
    final ffmpegCoomand = '-i $videoFilePath -q:v 1 -vcodec png $localPath/$exportPrefix%05d.png';
    await FFmpegKit.execute(ffmpegCoomand).then((session) async {
      final returnCode = await session.getReturnCode();

      // エラーまたは中断
      if (ReturnCode.isCancel(returnCode) || !ReturnCode.isSuccess(returnCode)) {
        return null;
      }
    }).onError((error, stackTrace) {
      return null;
    });

    return getFFmpegFiles();
  }

  List<File> getFFmpegFiles() {
    List<File> files = [];
    final localDirectory = Directory(localPath);

    List<FileSystemEntity> fileEntities =
        localDirectory.listSync(recursive: true, followLinks: false);
    for (var entity in fileEntities) {
      final fileName = entity.path.split('/').last;
      if (fileName.startsWith('ffmpeg_')) {
        files.add(File(entity.path));
      }
    }
    return files;
  }

  Future<bool> paintAllLandmarks({required BuildContext context}) async {
    const exportPrefix = 'ffmpeg_';

    var complete = false;
    var succeed = true;
    var index = 1;

    while (!complete) {
      try {
        final frameFileName = '$exportPrefix${index.toString().padLeft(5, '0')}.png';
        final frameFilePath = '$localPath/$frameFileName';

        final fileExist = await paintLandmarks(
          context: context,
          frameFilePath: frameFilePath,
        );

        complete = !fileExist;
      } catch (e) {
        succeed = false;
        complete = true;
      }
      index += 1;
    }

    return succeed;
  }

  // ウィジットを画像化してパスに保存
  Future<bool> paintLandmarks({
    required BuildContext context,
    required String frameFilePath,
  }) async {
    // ファイル
    final imageFile = File(frameFilePath);
    if (imageFile.existsSync()) {
      // ボーズ推定
      final inputImage = InputImage.fromFile(imageFile);
      final poseDetector = PoseDetector(options: PoseDetectorOptions());
      await poseDetector.processImage(inputImage).then((value) async {
        final pose = value.first;

        // 画像のデコード
        final imageByte = await imageFile.readAsBytes();
        final image = await decodeImageFromList(imageByte);

        // キャンバス上でランドマークの描画
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = LankmarkPainter(image: image, pose: pose);
        painter.paint(canvas, Size(videoWidth.toDouble(), videoHeight.toDouble()));

        // ランドマーク付き画像ByteData生成
        final ui.Picture picture = recorder.endRecording();
        final ui.Image imageRecorded = await picture.toImage(videoWidth, videoHeight);
        final ByteData? byteData = await imageRecorded.toByteData(format: ui.ImageByteFormat.png);

        // 上書き保存
        await File(imageFile.path).writeAsBytes(byteData!.buffer.asInt8List());
      });
      return true;
    } else {
      return false;
    }
  }

  Future<String?> createVideoFromFrames() async {
    const exportPrefix = 'ffmpeg_';
    final exportVideoFilePath = '$localPath/ffmpeg_video.mp4';
    final ffmpegCommand =
        '-framerate $videoFps -i $localPath/$exportPrefix%05d.png -r $videoFps $exportVideoFilePath';

    var succeed = false;

    await FFmpegKit.execute(ffmpegCommand).then((session) async {
      final returnCode = await session.getReturnCode();
      succeed = ReturnCode.isSuccess(returnCode);
    });

    if (succeed) {
      return exportVideoFilePath;
    } else {
      return null;
    }
  }
}
