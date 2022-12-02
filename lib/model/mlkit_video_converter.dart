import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/model/landmark_painter.dart';
import 'package:flutter_mlkit_video/utility/utilities.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class MlkitVideoConverter {
  late final String localPath;
  late final String videoFilePath;
  late final int videoWidth;
  late final int videoHeight;
  late final double videoFps;

  // メタデータ取得などの初期化処理
  Future<void> initialize({
    required String localPath,
    required String videoFilePath,
  }) async {
    final Map<String, dynamic>? videoInfo = await getVideoMetadata(videoFilePath);
    this.localPath = localPath;
    this.videoFilePath = videoFilePath;
    videoWidth = videoInfo!['width'];
    videoHeight = videoInfo['height'];
    videoFps = videoInfo['fps'];
  }

  // ビデオをフレームに分割してPNG画像として保存
  Future<List<File>?> convertVideoToFrames() async {
    await removeFFmpegFiles();

    // フレーム抽出
    final ffmpegCoomand =
        '-i $videoFilePath -q:v 1 -vcodec png $localPath/${CommonValue.filePrefix}%05d.png';
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
      if (fileName.startsWith(CommonValue.filePrefix)) {
        files.add(File(entity.path));
      }
    }
    return files;
  }

  // フレームにポーズ推定結果を描画してに上書き保存
  Future<bool> paintLandmarks({required String frameFileDirPath}) async {
    // ファイル
    final imageFile = File(frameFileDirPath);
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

  // フレームから動画を再生成
  Future<String?> createVideoFromFrames() async {
    final exportVideoFilePath = '$localPath/ffmpeg_video.mp4';
    final ffmpegCommand =
        '-framerate $videoFps -i $localPath/${CommonValue.filePrefix}%05d.png -b 100M -r $videoFps $exportVideoFilePath';

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
