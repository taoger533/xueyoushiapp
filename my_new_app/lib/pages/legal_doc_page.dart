import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class LegalDocPage extends StatefulWidget {
  final String type; // 'terms' 或 'privacy'
  const LegalDocPage({super.key, required this.type});

  @override
  State<LegalDocPage> createState() => _LegalDocPageState();
}

class _LegalDocPageState extends State<LegalDocPage> {
  String? _htmlContent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchDoc();
  }

  Future<void> _fetchDoc() async {
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/api/legal/docs?type=${widget.type}'),
      );
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _htmlContent = data['contentHtml'] ?? '';
          _loading = false;
        });
      } else {
        setState(() {
          _htmlContent = '<p>加载失败：${resp.statusCode}</p>';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _htmlContent = '<p>加载出错：$e</p>';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == 'terms' ? '用户服务协议' : '隐私政策'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_htmlContent ?? ''),
            ),
    );
  }
}
