import 'dart:io';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';

// アプリからファイルを保存するディレクトリのパス
Future<String> localFilePath() async {
  Directory tmpDocDir = await getTemporaryDirectory();
  print(tmpDocDir.path);
  return tmpDocDir.path;
}

// ビデオのメタデータ取得
Future<Map<String, dynamic>?> getVideoMetadata(String videoFilePath) async {
  Map<String, dynamic>? videoInfo;
  await FFprobeKit.getMediaInformation(videoFilePath).then((value) {
    final mediaInfoRaw = value.getMediaInformation()!.getAllProperties()!['streams'].first;
    videoInfo = Map<String, dynamic>.from(mediaInfoRaw);
  });
  return videoInfo;
}

Future<bool> createVideo({
  required BuildContext context,
  required String localPath,
  required String videoFilePath,
}) async {
  const exportPrefix = 'ffmpeg_';

  // メタデータ取得
  final Map<String, dynamic>? videoInfo = await getVideoMetadata(videoFilePath);
  final int videoWidth = videoInfo!['coded_width'];
  final int videoHeight = videoInfo['coded_height'];
  late final double videoFps;
  if (videoInfo['r_frame_rate'] != null) {
    final List<String> fraction = videoInfo['r_frame_rate']!.toString().split('/');
    videoFps = double.parse(fraction[0]) / double.parse(fraction[1]);
  }

  print([videoWidth, videoHeight, videoFps]);

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
          await _createVideoFromFrames(localPath: localPath, videoFps: videoFps);
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

Future<bool> _paintAllLandmarks({
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

      final fileExist = await _paintLandmarks(
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
Future<bool> _paintLandmarks(
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

Future<void> _createVideoFromFrames({
  required String localPath,
  required double videoFps,
}) async {
  const exportPrefix = 'ffmpeg_';

  final ffmpegCommand =
      '-framerate $videoFps -i $localPath/$exportPrefix%05d.png -b 800k -r $videoFps $localPath/video.mp4';

  await FFmpegKit.execute(ffmpegCommand).then((session) async {
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      // Finish
      print('done');
    } else if (ReturnCode.isCancel(returnCode)) {
      print('cancel');
    } else {
      print('error');
    }
  });
}

class LankmarkPainter extends CustomPainter {
  LankmarkPainter({
    required this.pose,
    required this.imageWidth,
    required this.imageHeight,
    required this.screenWidth,
    required this.image,
  });
  final Pose pose;
  final int imageWidth;
  final int imageHeight;
  final double screenWidth;
  final ui.Image image;

  List<PoseLandmarkType> get faceParts => [
        PoseLandmarkType.leftEyeInner,
        PoseLandmarkType.leftEye,
        PoseLandmarkType.leftEyeOuter,
        PoseLandmarkType.rightEyeInner,
        PoseLandmarkType.rightEye,
        PoseLandmarkType.rightEyeOuter,
        PoseLandmarkType.leftEar,
        PoseLandmarkType.rightEar,
        PoseLandmarkType.leftMouth,
        PoseLandmarkType.rightMouth,
      ];
  List<PoseLandmarkType> get rightArm => [
        PoseLandmarkType.rightShoulder,
        PoseLandmarkType.rightElbow,
        PoseLandmarkType.rightWrist,
        PoseLandmarkType.rightThumb,
        PoseLandmarkType.rightIndex,
        PoseLandmarkType.rightPinky,
      ];
  List<PoseLandmarkType> get leftArm => [
        PoseLandmarkType.leftShoulder,
        PoseLandmarkType.leftElbow,
        PoseLandmarkType.leftWrist,
        PoseLandmarkType.leftThumb,
        PoseLandmarkType.leftIndex,
        PoseLandmarkType.leftPinky,
      ];
  List<PoseLandmarkType> get leftLeg => [
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.leftHeel,
        PoseLandmarkType.leftFootIndex,
      ];
  List<PoseLandmarkType> get rightLeg => [
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
        PoseLandmarkType.rightHeel,
        PoseLandmarkType.rightFootIndex,
      ];

  @override
  void paint(canvas, size) async {
    const strokeWidth = 4.0;

    // 画像の描画
    canvas.drawImage(image, Offset.zero, Paint());

    // ランドマークのペイント
    // 胴体
    final paint = Paint()
      ..color = Colors.grey
      ..strokeWidth = strokeWidth;
    final p1 = Offset(pose.landmarks[rightArm.first]!.x, pose.landmarks[rightArm.first]!.y);
    final p2 = Offset(pose.landmarks[leftArm.first]!.x, pose.landmarks[leftArm.first]!.y);
    final p3 = Offset(pose.landmarks[leftLeg.first]!.x, pose.landmarks[leftLeg.first]!.y);
    final p4 = Offset(pose.landmarks[rightLeg.first]!.x, pose.landmarks[rightLeg.first]!.y);
    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p2, p3, paint);
    canvas.drawLine(p3, p4, paint);
    canvas.drawLine(p4, p1, paint);

    // 左腕
    for (var index = 0; index < leftArm.length - 1; index++) {
      final landmark1 = leftArm[index];
      final landmark2 = leftArm[index + 1];
      final paint = Paint()
        ..color = landmark1.color
        ..strokeWidth = strokeWidth;
      final p1 = Offset(pose.landmarks[landmark1]!.x, pose.landmarks[landmark1]!.y);
      final p2 = Offset(pose.landmarks[landmark2]!.x, pose.landmarks[landmark2]!.y);
      canvas.drawCircle(p1, strokeWidth, paint);
      if (index < leftArm.length - 1) {
        canvas.drawLine(p1, p2, paint);
      }
    }

    // 右腕
    for (var index = 0; index < rightArm.length - 1; index++) {
      final landmark1 = rightArm[index];
      final landmark2 = rightArm[index + 1];
      final paint = Paint()
        ..color = landmark1.color
        ..strokeWidth = strokeWidth;
      final p1 = Offset(pose.landmarks[landmark1]!.x, pose.landmarks[landmark1]!.y);
      final p2 = Offset(pose.landmarks[landmark2]!.x, pose.landmarks[landmark2]!.y);
      canvas.drawCircle(p1, strokeWidth, paint);
      if (index < rightArm.length - 1) {
        canvas.drawLine(p1, p2, paint);
      }
    }

    // 左脚
    for (var index = 0; index < leftLeg.length - 1; index++) {
      final landmark1 = leftLeg[index];
      final landmark2 = leftLeg[index + 1];
      final paint = Paint()
        ..color = landmark1.color
        ..strokeWidth = strokeWidth;
      final p1 = Offset(pose.landmarks[landmark1]!.x, pose.landmarks[landmark1]!.y);
      final p2 = Offset(pose.landmarks[landmark2]!.x, pose.landmarks[landmark2]!.y);
      canvas.drawCircle(p1, strokeWidth, paint);
      if (index < leftLeg.length - 1) {
        canvas.drawLine(p1, p2, paint);
      }
    }

    // 右脚
    for (var index = 0; index < rightLeg.length - 1; index++) {
      final landmark1 = rightLeg[index];
      final landmark2 = rightLeg[index + 1];
      final paint = Paint()
        ..color = landmark1.color
        ..strokeWidth = strokeWidth;
      final p1 = Offset(pose.landmarks[landmark1]!.x, pose.landmarks[landmark1]!.y);
      final p2 = Offset(pose.landmarks[landmark2]!.x, pose.landmarks[landmark2]!.y);
      canvas.drawCircle(p1, strokeWidth, paint);
      if (index < rightLeg.length - 1) {
        canvas.drawLine(p1, p2, paint);
      }
    }

    // 顔
    for (var landmark in faceParts) {
      final paint = Paint()..color = landmark.color;
      final position = Offset(pose.landmarks[landmark]!.x, pose.landmarks[landmark]!.y);
      canvas.drawCircle(position, strokeWidth, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// ランドマークごとの色
extension PoseLandmarkColor on PoseLandmarkType {
  Color get color {
    if (this == PoseLandmarkType.rightHip ||
        this == PoseLandmarkType.rightKnee ||
        this == PoseLandmarkType.rightAnkle ||
        this == PoseLandmarkType.rightHeel ||
        this == PoseLandmarkType.rightFootIndex) {
      return Colors.blue;
    } else if (this == PoseLandmarkType.leftHip ||
        this == PoseLandmarkType.leftKnee ||
        this == PoseLandmarkType.leftAnkle ||
        this == PoseLandmarkType.leftHeel ||
        this == PoseLandmarkType.leftFootIndex) {
      return Colors.pink;
    } else if (this == PoseLandmarkType.leftShoulder ||
        this == PoseLandmarkType.leftElbow ||
        this == PoseLandmarkType.leftWrist ||
        this == PoseLandmarkType.leftPinky ||
        this == PoseLandmarkType.leftIndex ||
        this == PoseLandmarkType.leftThumb) {
      return Colors.deepPurple;
    } else if (this == PoseLandmarkType.rightShoulder ||
        this == PoseLandmarkType.rightElbow ||
        this == PoseLandmarkType.rightWrist ||
        this == PoseLandmarkType.rightPinky ||
        this == PoseLandmarkType.rightIndex ||
        this == PoseLandmarkType.rightThumb) {
      return Colors.green;
    } else {
      return Colors.amber;
    }
  }
}
