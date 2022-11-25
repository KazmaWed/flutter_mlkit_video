import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/video_view.dart';

class MlkitScreen extends StatefulWidget {
  const MlkitScreen({super.key});

  @override
  State<MlkitScreen> createState() => _MlkitScreenState();
}

class _MlkitScreenState extends State<MlkitScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google ML Kit'),
      ),
      body: const SafeArea(
        child: VideoView(),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.video_file_rounded),
        onPressed: () {},
      ),
    );
  }
}
