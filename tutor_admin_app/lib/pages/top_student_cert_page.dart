import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class TopStudentCert {
  final String id;
  final String username;
  final String role;
  final String university;
  final String major;
  final String idFrontUrl;
  final String idBackUrl;
  final String studentIdUrl;
  final List<String> suppUrls;
  String status;
  int titleCode;

  TopStudentCert({
    required this.id,
    required this.username,
    required this.role,
    required this.university,
    required this.major,
    required this.idFrontUrl,
    required this.idBackUrl,
    required this.studentIdUrl,
    required this.suppUrls,
    required this.status,
    required this.titleCode,
  });

  factory TopStudentCert.fromJson(Map<String, dynamic> json) {
    final user = json['userId'] ?? {};
    String fullUrl(String path) {
      if (path.isEmpty) return '';
      if (path.startsWith('http')) return path;
      return '$apiBase'.replaceFirst('/api', '') + path;
    }

    return TopStudentCert(
      id: json['_id'] ?? '',
      username: user['username'] ?? '未知',
      role: user['role'] ?? 'unknown',
      university: json['university'] ?? '',
      major: json['major'] ?? '',
      idFrontUrl: fullUrl(json['idFrontUrl'] ?? ''),
      idBackUrl: fullUrl(json['idBackUrl'] ?? ''),
      studentIdUrl: fullUrl(json['studentIdUrl'] ?? ''),
      suppUrls: (json['suppUrls'] as List<dynamic>? ?? [])
          .map((e) => fullUrl(e.toString()))
          .toList(),
      status: json['status'] ?? 'pending',
      titleCode: user['titleCode'] ?? 0,
    );
  }
}

class TopStudentCertPage extends StatefulWidget {
  const TopStudentCertPage({super.key});

  @override
  State<TopStudentCertPage> createState() => _TopStudentCertPageState();
}

class _TopStudentCertPageState extends State<TopStudentCertPage> {
  List<TopStudentCert> certs = [];
  bool isLoading = true;

  /// 拉取认证申请列表
  Future<void> fetchCerts() async {
    setState(() => isLoading = true);
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/api/top-student-certification/admin/list'),
      );
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        certs = data.map((e) => TopStudentCert.fromJson(e)).toList();
      } else {
        debugPrint('获取认证列表失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
    setState(() => isLoading = false);
  }

  /// 更新认证状态（通过或否认），并更新用户 titleCode
  Future<void> updateStatus(TopStudentCert cert, String action) async {
    final url = '$apiBase/api/top-student-certification/admin/$action/${cert.id}';
    try {
      final resp = await http.patch(Uri.parse(url));
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cert.username} 认证已${action == 'approve' ? '通过' : '否认'}')),
        );

        if (action == 'approve') {
          await updateUserTitleCode(cert);
        }

        await fetchCerts();
      } else {
        debugPrint('审核失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
  }

  /// 审核通过后更新用户 titleCode
  Future<void> updateUserTitleCode(TopStudentCert cert) async {
    // 若原为 1（专业教员），则变为 3；否则直接为 2（学霸大学生）
    final newCode = (cert.titleCode == 1) ? 3 : 2;
    final url = '$apiBase/api/admin/user/${cert.id}/title-code';
    try {
      final resp = await http.patch(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'titleCode': newCode}),
      );
      if (resp.statusCode == 200) {
        debugPrint('titleCode 更新成功: $newCode');
      } else {
        debugPrint('titleCode 更新失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
  }

  /// 缩略图 + 点击放大
  Widget _buildImagePreview(String url) {
    if (url.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(10),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Image.network(url, height: 80, fit: BoxFit.cover),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchCerts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学霸大学生认证管理')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchCerts,
              child: certs.isEmpty
                  ? const Center(child: Text('暂无认证申请'))
                  : ListView.builder(
                      itemCount: certs.length,
                      itemBuilder: (context, index) {
                        final cert = certs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('申请人: ${cert.username} (${cert.role})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('学校: ${cert.university}'),
                                Text('专业: ${cert.major}'),
                                Text('状态: ${cert.status}'),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildImagePreview(cert.idFrontUrl),
                                    _buildImagePreview(cert.idBackUrl),
                                    _buildImagePreview(cert.studentIdUrl),
                                    ...cert.suppUrls.map(_buildImagePreview).toList(),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ElevatedButton(
                                      onPressed: cert.status == 'approved'
                                          ? null
                                          : () => updateStatus(cert, 'approve'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      child: const Text('通过'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      onPressed: cert.status == 'rejected'
                                          ? null
                                          : () => updateStatus(cert, 'reject'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('否认'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
