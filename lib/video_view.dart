import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/utilities.dart';
import 'package:image_picker/image_picker.dart';

class VideoView extends StatefulWidget {
  const VideoView({super.key, this.videoXFile});
  final XFile? videoXFile;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late Future _future;

  // ビデオの情報
  late String localPath;

  final exportPrefix = 'ffmpeg_'; // 保存するフレーム画像のファイル名接頭辞

  var _busy = false; // 画像化処理の連続実行ガード用

  // ビデオの前フレームにランドマークを乗せて保存
  Future<void> _convertVideo(String? videoFilePath) async {
    localPath = await localFilePath();
    print(videoFilePath);

    if (!_busy) {
      // ファイル未選択時
      if (videoFilePath == null) return;
      setState(() => _busy = true);

      // フレーム抽出
      await createVideo(
        context: context,
        localPath: localPath,
        videoFilePath: videoFilePath,
      ).then((succeed) {
        setState(() => _busy = false);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // ポーズ推定開始
    _future = _convertVideo(widget.videoXFile?.path);
  }

  @override
  Widget build(BuildContext context) {
    return widget.videoXFile == null
        ? Container(
            alignment: Alignment.center,
            child: const Text('ファイルを選択してください'),
          )
        : FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Container(
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(),
                );
              } else if (snapshot.hasError) {
                return Container(
                  alignment: Alignment.center,
                  child: Text(snapshot.error.toString()),
                );
              } else {
                _future = Future.value(null);

                return Container(
                  alignment: Alignment.center,
                  child: const Text('終了'),
                );
              }
            },
          );
  }
}
