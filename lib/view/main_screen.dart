import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/view/video_convert_view.dart';
import 'package:image_picker/image_picker.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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
        child: ElevatedButton(
          child: const Text('ファイル選択'),
          onPressed: () async => _pickVideo(),
        ),
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
        ));
  }
}
