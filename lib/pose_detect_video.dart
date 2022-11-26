import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/landmark_painter.dart';
import 'package:flutter_mlkit_video/utilities.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PoseDetectVideo {
  static Future<bool> createVideo({
    required BuildContext context,
    required String localPath,
    required String videoFilePath,
  }) async {
    const exportPrefix = 'ffmpeg_';

    // メタデータ取得
    final Map<String, dynamic>? videoInfo = await getVideoMetadata(videoFilePath);
    final int videoWidth = videoInfo!['width'];
    final int videoHeight = videoInfo['height'];
    final double videoFps = videoInfo['fps'];

    // フレーム抽出
    final ffmpegCoomand = '-i $videoFilePath -q:v 1 -vcodec png $localPath/$exportPrefix%05d.png';
    await FFmpegKit.execute(ffmpegCoomand).then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        // 前フレームにランドマークペイント追加
        await _paintAllLandmarks(
          context: context,
          localPath: localPath,
          videoWidth: videoWidth,
          videoHeight: videoHeight,
        ).then((succeed) async {
          if (succeed) {
            await createVideoFromFrames(localPath: localPath, videoFps: videoFps);
            await saveToCameraRoll();
            await removeFiles();
          }
        });
      } else if (ReturnCode.isCancel(returnCode)) {
        return false; // Cancel
      } else {
        return false; // Error
      }
    }).onError((error, stackTrace) {
      print(error);
      return false;
    });
    return true;
  }

  static Future<bool> _paintAllLandmarks({
    required BuildContext context,
    required String localPath,
    required int videoWidth,
    required int videoHeight,
  }) async {
    const exportPrefix = 'ffmpeg_';

    var complete = false;
    var succeed = true;
    var index = 1;

    while (!complete) {
      print(index);
      try {
        final frameFileName = '$exportPrefix${index.toString().padLeft(5, '0')}.png';
        final frameFilePath = '$localPath/$frameFileName';

        final fileExist = await paintLandmarks(
          context: context,
          frameFilePath: frameFilePath,
          videoWidth: videoWidth,
          videoHeight: videoHeight,
        );

        complete = !fileExist;
      } catch (e) {
        print(e);
        succeed = false;
        complete = true;
      }
      index += 1;
    }

    return succeed;
  }

// ウィジットを画像化してパスに保存
  static Future<bool> paintLandmarks(
      {required BuildContext context,
      required String frameFilePath,
      required int videoWidth,
      required int videoHeight}) async {
    // ファイル
    final imageFile = File(frameFilePath);
    if (imageFile.existsSync()) {
      final screenWidth = MediaQuery.of(context).size.width;

      // ボーズ推定
      final inputImage = InputImage.fromFile(imageFile);
      final poseDetector = PoseDetector(options: PoseDetectorOptions());
      await poseDetector.processImage(inputImage).then((value) async {
        final pose = value.first;

        final imageByte = await imageFile.readAsBytes();
        final image = await decodeImageFromList(imageByte);

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final painter = LankmarkPainter(
          image: image,
          pose: pose,
          imageWidth: videoWidth,
          imageHeight: videoHeight,
          screenWidth: screenWidth,
        );
        painter.paint(canvas, Size(videoWidth.toDouble(), videoHeight.toDouble()));

        final ui.Picture picture = recorder.endRecording();
        final ui.Image imageRecorded = await picture.toImage(videoWidth, videoHeight);
        final ByteData? byteData = await imageRecorded.toByteData(format: ui.ImageByteFormat.png);

        await File(imageFile.path).writeAsBytes(byteData!.buffer.asInt8List());
      });
      return true;
    } else {
      return false;
    }
  }

  static Future<bool> createVideoFromFrames({
    required String localPath,
    required double videoFps,
  }) async {
    const exportPrefix = 'ffmpeg_';

    final ffmpegCommand =
        '-framerate $videoFps -i $localPath/$exportPrefix%05d.png -b 800k -r $videoFps $localPath/ffmpeg_video.mp4';

    await FFmpegKit.execute(ffmpegCommand).then((session) async {
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        return true;
      }
    });
    return false;
  }
}
