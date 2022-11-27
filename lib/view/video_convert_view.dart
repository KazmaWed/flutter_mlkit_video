import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/model/mlkit_video_converter.dart';
import 'package:flutter_mlkit_video/utility/utilities.dart';
import 'package:image_picker/image_picker.dart';

class VideoView extends StatefulWidget {
  const VideoView({super.key, this.videoXFile});
  final XFile? videoXFile;

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late Future _future;

  var _busy = false; // 画像化処理の連続実行ガード用
  var _completion = 0.0; // 完了率

  // ビデオの全フレームにランドマークをペイントして保存
  Future<void> _convertVideo() async {
    if (!_busy) {
      // 開始
      setState(() => _busy = true);

      // 選択したファイルパス
      final videoFilePath = widget.videoXFile?.path;
      // 作成したファイルの保存先パス
      final localPath = await localFilePath();

      // ファイル未選択時ガード
      if (videoFilePath == null) return;

      // コンバーター初期化
      final mlkitVideoConverter = MlkitVideoConverter(localPath: localPath);
      await mlkitVideoConverter.initialize(videoFilePath: videoFilePath);
      // フレーム抽出
      final frameImageFiles = await mlkitVideoConverter.convertVideoToFrames(context: context);
      // 全フレームにランドマークをペイント
      if (frameImageFiles != null) {
        for (var index = 0; index < frameImageFiles.length; index++) {
          final file = frameImageFiles[index];
          await mlkitVideoConverter.paintLandmarks(context: context, frameFilePath: file.path);
          setState(() => _completion = index / frameImageFiles.length); // プログレス更新
        }
      }
      // フレームから動画生成
      final exportFilePath = await mlkitVideoConverter.createVideoFromFrames();
      // カメラロールに保存
      if (exportFilePath != null) {
        await saveToCameraRoll(exportFilePath);
      }
      // キャッシュクリア
      await removeFFmpegFiles();

      // 完了ダイアログ表示
      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            // title: const Text('カメラロールに保存しました'),
            content: const Text('カメラロールに保存しました'),
            actions: [
              TextButton(child: const Text('OK'), onPressed: () => Navigator.pop(context)),
            ],
          );
        },
      );

      //  終了
      setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // ポーズ推定開始
    _future = _convertVideo();
  }

  @override
  Widget build(BuildContext context) {
    return widget.videoXFile == null
        // ---------- ファイル選択前 ----------
        ? Container(
            alignment: Alignment.center,
            child: const Text('ファイルを選択してください'),
          )
        // ---------- ファイル選択後 ----------
        : FutureBuilder(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                // ---------- 処理中 ----------
                return Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('書き出し中'),
                      const SizedBox(height: 16),
                      CircularProgressIndicator(
                        value: _completion,
                        backgroundColor: Colors.black12,
                      ),
                    ],
                  ),
                );
              } else if (snapshot.hasError) {
                // ---------- エラー発生時 ----------
                return Container(
                  alignment: Alignment.center,
                  child: Text(snapshot.error.toString()),
                );
              } else {
                // ---------- 完了 ----------
                return Container(
                  alignment: Alignment.center,
                  child: const Text('カメラロールに保存しました'),
                );
              }
            },
          );
  }
}
