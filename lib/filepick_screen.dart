import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/video_view.dart';
import 'package:image_picker/image_picker.dart';

class MlkitScreen extends StatefulWidget {
  const MlkitScreen({super.key});

  @override
  State<MlkitScreen> createState() => _MlkitScreenState();
}

class _MlkitScreenState extends State<MlkitScreen> {
  XFile? _videoPicked;
  late Widget videoView;

  Future<void> _pickVideo() async {
    // ギャラリーからビデオを選択
    await ImagePicker().pickVideo(source: ImageSource.gallery).then((result) {
      if (result != null) {
        _videoPicked = result;
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_videoPicked == null) {
      videoView = Container(
        alignment: Alignment.center,
        child: const Text('ファイルを選択して下さい'),
      );
    } else {
      videoView = VideoView(videoXFile: _videoPicked);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google ML Kit'),
      ),
      body: SafeArea(
        child: videoView,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.video_file_rounded),
        onPressed: () async => _pickVideo(),
      ),
    );
  }
}
