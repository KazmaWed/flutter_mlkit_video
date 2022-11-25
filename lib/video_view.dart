import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VideoView extends StatefulWidget {
  const VideoView({super.key, this.videoXFile});
  final XFile? videoXFile;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Text(widget.videoXFile == null ? '未選択' : widget.videoXFile!.path),
    );
  }
}
