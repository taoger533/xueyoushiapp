import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ProfessionalCert {
  final String id;
  final String username;
  final String role;
  final String school;
  final String major;
  final String idFrontUrl;
  final String idBackUrl;
  final String certificateUrl;
  String status;
  int titleCode;

  ProfessionalCert({
    required this.id,
    required this.username,
    required this.role,
    required this.school,
    required this.major,
    required this.idFrontUrl,
    required this.idBackUrl,
    required this.certificateUrl,
    required this.status,
    required this.titleCode,
  });

  factory ProfessionalCert.fromJson(Map<String, dynamic> json) {
    final user = json['userId'] ?? {};
    String fullUrl(String path) {
      if (path.isEmpty) return '';
      if (path.startsWith('http')) return path;
      return '$apiBase'.replaceFirst('/api', '') + path;
    }

    return ProfessionalCert(
      id: json['_id'] ?? '',
      username: user['username'] ?? '未知',
      role: user['role'] ?? 'unknown',
      school: json['school'] ?? '',
      major: json['major'] ?? '',
      idFrontUrl: fullUrl(json['idFrontUrl'] ?? ''),
      idBackUrl: fullUrl(json['idBackUrl'] ?? ''),
      certificateUrl: fullUrl(json['certificateUrl'] ?? ''),
      status: json['status'] ?? 'pending',
      titleCode: user['titleCode'] ?? 0,
    );
  }
}

class ProfessionalCertPage extends StatefulWidget {
  const ProfessionalCertPage({super.key});

  @override
  State<ProfessionalCertPage> createState() => _ProfessionalCertPageState();
}

class _ProfessionalCertPageState extends State<ProfessionalCertPage> {
  List<ProfessionalCert> certs = [];
  bool isLoading = true;

  /// 拉取认证申请列表
  Future<void> fetchCerts() async {
    setState(() => isLoading = true);
    try {
      final resp = await http.get(
        Uri.parse('$apiBase/api/professional-certification/admin/list'),
      );
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        certs = data.map((e) => ProfessionalCert.fromJson(e)).toList();
      } else {
        debugPrint('获取认证列表失败: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      debugPrint('网络错误: $e');
    }
    setState(() => isLoading = false);
  }

  /// 审核操作（通过或否认）
  Future<void> updateStatus(ProfessionalCert cert, String action) async {
    final url = '$apiBase/api/professional-certification/admin/$action/${cert.id}';
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
  Future<void> updateUserTitleCode(ProfessionalCert cert) async {
    final newCode = (cert.titleCode == 2) ? 3 : 1;
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

  /// 构建可点击图片（缩略图 + 全屏预览）
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
      appBar: AppBar(title: const Text('专业教员认证管理')),
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
                                Text('学校: ${cert.school}'),
                                Text('专业: ${cert.major}'),
                                Text('状态: ${cert.status}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (cert.idFrontUrl.isNotEmpty)
                                      Expanded(child: _buildImagePreview(cert.idFrontUrl)),
                                    const SizedBox(width: 8),
                                    if (cert.idBackUrl.isNotEmpty)
                                      Expanded(child: _buildImagePreview(cert.idBackUrl)),
                                    const SizedBox(width: 8),
                                    if (cert.certificateUrl.isNotEmpty)
                                      Expanded(child: _buildImagePreview(cert.certificateUrl)),
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
