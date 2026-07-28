import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lanxi/core/logger.dart';
import 'package:lanxi/services/server_service.dart';

/// 全屏图片查看页（迁移自旧 Lanxi，按 Lanxi1 架构改用 [ServerService] 读取字节）。
///
/// 直接用内置 [InteractiveViewer] 提供缩放/平移，避免引入额外依赖。
class ImagePreviewPage extends StatefulWidget {
  final ServerService service;
  final String path;
  final String name;

  const ImagePreviewPage({
    super.key,
    required this.service,
    required this.path,
    required this.name,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late final Future<Uint8List> _loader;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loader = widget.service.readFileBytes(widget.path).catchError((e) {
      _error = e;
      appLogger.e('图片预览加载失败：${widget.path}', e);
      return Uint8List(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: FutureBuilder<Uint8List>(
        future: _loader,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final bytes = snap.data;
          if (_error != null || bytes == null || bytes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    _error != null ? '加载失败：$_error' : '空文件',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(child: Image.memory(bytes)),
          );
        },
      ),
    );
  }
}
