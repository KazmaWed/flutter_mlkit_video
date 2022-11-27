import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class LankmarkPainter extends CustomPainter {
  LankmarkPainter({
    required this.pose,
    required this.image,
  });
  final Pose pose;
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