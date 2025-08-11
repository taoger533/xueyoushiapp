import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../config.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';


class ImageUploadBox extends StatefulWidget {
  final String label;
  final void Function(String url)? onUploaded;

  const ImageUploadBox({
    super.key,
    required this.label,
    this.onUploaded,
  });

  @override
  State<ImageUploadBox> createState() => _ImageUploadBoxState();
}

class _ImageUploadBoxState extends State<ImageUploadBox> {
  XFile? _selectedFile;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  Future<File?> _compressImage(File file, {int quality = 70}) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}');

    // 使用 flutter_image_compress 压缩
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: quality,
      format: CompressFormat.jpeg,
    );

    return result != null ? File(result.path) : null;
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() {
      _isUploading = true;
    });

    final original = File(picked.path);
    final compressed = await _compressImage(original);
    if (compressed == null) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片压缩失败')),
      );
      return;
    }

    try {
      final uri = Uri.parse('$apiBase/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('image', compressed.path));
      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final imageUrl = data['url'];

        setState(() {
          _selectedFile = picked;
          _isUploading = false;
        });

        if (widget.onUploaded != null) {
          widget.onUploaded!(imageUrl);
        }
      } else {
        throw Exception('上传失败');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上传失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploading ? null : _pickAndUpload,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
                style: BorderStyle.solid,
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isUploading
                ? const Center(child: CircularProgressIndicator())
                : _selectedFile == null
                    ? const Center(child: Icon(Icons.add, size: 36, color: Colors.grey))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(_selectedFile!.path),
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}
