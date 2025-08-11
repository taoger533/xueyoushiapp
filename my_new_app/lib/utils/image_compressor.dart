import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 压缩图像并返回 File
Future<File?> compressImage(File file, {int quality = 70}) async {
  final dir = await getTemporaryDirectory();
  final targetPath = p.join(
    dir.path,
    '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}',
  );

  final result = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    quality: quality,
    format: CompressFormat.jpeg,
  );

  return result != null ? File(result.path) : null; // ✅ 转换为 File 类型
}
