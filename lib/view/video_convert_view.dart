import 'package:flutter/material.dart';
import 'package:flutter_mlkit_video/model/mlkit_video_converter.dart';
import 'package:flutter_mlkit_video/utility/utilities.dart';
import 'package:image_picker/image_picker.dart';

class VideoConvertView extends StatefulWidget {
  const VideoConvertView({super.key, this.videoXFile});
  final XFile? videoXFile;

  @override
  State<VideoConvertView> createState() => _VideoConvertViewState();
}

class _VideoConvertViewState extends State<VideoConvertView> {
  late Future<void> _future;

  var _busy = false; // 処理実行中ガード
  var _progress = 0.0; // 処理の完了率

  // ビデオの全フレームにランドマークを描画してカメラロールに保存
  Future<void> _convertVideo() async {
    if (!_busy) {
      // 開始
      _busy = true;

      // 選択したファイルパス
      final videoFilePath = widget.videoXFile?.path;
      // ファイル未選択時ガード
      if (videoFilePath == null) return;

      // 作成したファイルの保存先パス
      final localPath = await getLocalPath();

      // キャッシュクリア
      await removeFFmpegFiles();

      // コンバーターの作成と初期化
      final mlkitVideoConverter = MlkitVideoConverter();
      await mlkitVideoConverter.initialize(
        localPath: localPath,
        videoFilePath: videoFilePath,
      );
      // ビデオからフレーム抽出
      final frameImageFiles = await mlkitVideoConverter.convertVideoToFrames();
      // 全フレームにランドマークを描画
      if (frameImageFiles != null) {
        for (var index = 0; index < frameImageFiles.length; index++) {
          final file = frameImageFiles[index];
          await mlkitVideoConverter.paintLandmarks(frameFileDirPath: file.path);
          setState(() => _progress = index / frameImageFiles.length); // プログレス更新
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
            content: const Text('カメラロールに保存しました'),
            actions: [
              TextButton(child: const Text('OK'), onPressed: () => Navigator.pop(context)),
            ],
          );
        },
      );

      //  終了
      _busy = false;
    }
  }

  // 処理中プログレスバー
  Widget _progressView(double value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('書き出し中'),
        const SizedBox(height: 16),
        CircularProgressIndicator(
          value: value,
          backgroundColor: Colors.black12,
        ),
      ],
    );
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
                  child: _progressView(_progress),
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
