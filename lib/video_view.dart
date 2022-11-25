import 'dart:io';
import 'dart:ui' as ui;
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mlkit_video/utilities.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class VideoView extends StatefulWidget {
  const VideoView({super.key, this.videoXFile});
  final XFile? videoXFile;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  final exportPrefix = 'ffmpeg_';
  final _globalKey = GlobalKey();
  Widget? imageView;
  var _busy = false;

  Future<String> _localPath() async {
    Directory tmpDocDir = await getTemporaryDirectory();
    return tmpDocDir.path;
  }

  Future<String?> _saveVideoFrames() async {
    if (widget.videoXFile != null) {
      if (!_busy) {
        _busy = true;
        print('start!');
        final localPath = await _localPath();
        print(localPath);

        final filePath = widget.videoXFile!.path;
        await FFmpegKit.execute('-i $filePath -q:v 1 -vcodec png $localPath/$exportPrefix%05d.png')
            .then((FFmpegSession session) async {
          final returnCode = await session.getReturnCode();

          if (ReturnCode.isSuccess(returnCode)) {
            // Finish
            await _drawPose();
            return filePath;
          } else if (ReturnCode.isCancel(returnCode)) {
            return null; // Cancel
          } else {
            return null; // Error
          }
        });
      } else {
        return null;
      }
      _busy = false;
      print('finish');
    }
    return null;
  }

  Future<void> convertWidgetToImage(File imageFile) async {
    const imageWidth = 1280;
    final screenWidth = MediaQuery.of(context).size.width;

    // ボーズ推定
    final inputImage = InputImage.fromFile(imageFile);
    final poseDetector = PoseDetector(options: PoseDetectorOptions());
    await poseDetector.processImage(inputImage).then((value) async {
      final List<Pose> poses = value;

      final landmarkPainLayer = CustomPaint(
        foregroundPainter: LankmarkPainter(
          pose: poses.first,
          imageWidth: imageWidth,
          screenWidth: screenWidth,
        ),
      );

      imageView = Stack(
        children: [
          Image.file(imageFile),
          landmarkPainLayer,
        ],
      );

      setState(() {});
      final boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final boundaryImage = await boundary.toImage(pixelRatio: imageWidth / screenWidth);
      final boundaryByteData = await boundaryImage.toByteData(format: ui.ImageByteFormat.png);
      await File(imageFile.path).writeAsBytes(boundaryByteData!.buffer.asInt8List());
    });
  }

  Future<void> _drawPose() async {
    var complete = false;
    final localPath = await _localPath();
    var index = 1;

    while (index < 100) {
      try {
        final frameFileName = '$exportPrefix${index.toString().padLeft(5, '0')}.png';
        final frameFilePath = '$localPath/$frameFileName';
        final imageFile = File(frameFilePath);

        await convertWidgetToImage(imageFile);
      } catch (e) {
        complete = true;
      }
      index += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    _saveVideoFrames();
    return Container(
      alignment: Alignment.center,
      child: widget.videoXFile == null
          ? const SelectableText('未選択')
          : imageView == null
              ? const Text('Wainting')
              : RepaintBoundary(
                  key: _globalKey,
                  child: imageView,
                ),
    );
  }
}
