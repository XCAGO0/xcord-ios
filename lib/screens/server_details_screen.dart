import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:xcord/screens/colors.dart';

class ServerDetailsScreen extends StatefulWidget {
  final String serverId;
  final String token;
  final Map<String, dynamic> basicInfo;

  const ServerDetailsScreen({
    super.key,
    required this.serverId,
    required this.token,
    required this.basicInfo,
  });

  @override
  State<ServerDetailsScreen> createState() => _ServerDetailsScreenState();
}

class _ServerDetailsScreenState extends State<ServerDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _serverDetails = {};
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadServerDetails();
  }

  Future<void> _loadServerDetails() async {
    try {
      // جلب تفاصيل السيرفر
      final serverResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}?with_counts=true'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );

      if (serverResponse.statusCode == 200) {
        _serverDetails = json.decode(serverResponse.body);
      }

      // جلب الأعضاء
      final membersResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/members?limit=1000'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );

      if (membersResponse.statusCode == 200) {
        _members = List<Map<String, dynamic>>.from(json.decode(membersResponse.body));
      }

      // جلب القنوات
      final channelsResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/channels'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );

      if (channelsResponse.statusCode == 200) {
        _channels = List<Map<String, dynamic>>.from(json.decode(channelsResponse.body));
      }

      // جلب الرتب
      final rolesResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/roles'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );

      if (rolesResponse.statusCode == 200) {
        _roles = List<Map<String, dynamic>>.from(json.decode(rolesResponse.body));
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل التفاصيل: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.cardBackground,
          elevation: 0,
          title: Text(
            'تفاصيل السيرفر',
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE91E63),
          ),
        ),
      );
    }

    final botCount = _members.where((m) => m['user']?['bot'] == true).length;
    final adminCount = _members.where((m) {
      final permissions = int.tryParse(m['permissions']?.toString() ?? '0') ?? 0;
      return (permissions & 0x8) == 0x8; // ADMINISTRATOR permission
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          widget.basicInfo['name'],
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Icon and Basic Info
            Row(
              children: [
                if (widget.basicInfo['icon'] != null)
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(
                      'https://cdn.discordapp.com/icons/${widget.serverId}/${widget.basicInfo['icon']}.png',
                    ),
                  )
                else
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFF2F3136),
                    child: Icon(Icons.discord, color: Colors.white, size: 40),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.basicInfo['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ID: ${widget.serverId}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Grid
            GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  'إجمالي الأعضاء',
                  _serverDetails['approximate_member_count']?.toString() ?? '0',
                  Icons.people,
                ),
                _buildStatCard(
                  'المتصلين',
                  _serverDetails['approximate_presence_count']?.toString() ?? '0',
                  Icons.person_outline,
                ),
                _buildStatCard(
                  'البوتات',
                  botCount.toString(),
                  Icons.smart_toy,
                ),
                _buildStatCard(
                  'المشرفين',
                  adminCount.toString(),
                  Icons.admin_panel_settings,
                ),
                _buildStatCard(
                  'القنوات',
                  _channels.length.toString(),
                  Icons.tag,
                ),
                _buildStatCard(
                  'الرتب',
                  _roles.length.toString(),
                  Icons.shield,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Additional Details
            Text(
              'معلومات إضافية',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow('المنطقة', _serverDetails['region'] ?? 'غير محدد'),
                    _buildDetailRow('مستوى التحقق', _getVerificationLevel(_serverDetails['verification_level'])),
                    _buildDetailRow('تاريخ الإنشاء', _formatDate(_serverDetails['id'])),
                    if (_serverDetails['vanity_url_code'] != null)
                      _buildDetailRow('رابط مخصص', _serverDetails['vanity_url_code']),
                    _buildDetailRow('عدد البوستات', _serverDetails['premium_subscription_count']?.toString() ?? '0'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _getVerificationLevel(int? level) {
    switch (level) {
      case 0:
        return 'لا يوجد';
      case 1:
        return 'منخفض';
      case 2:
        return 'متوسط';
      case 3:
        return 'عالي';
      case 4:
        return 'عالي جداً';
      default:
        return 'غير معروف';
    }
  }

  String _formatDate(String? snowflake) {
    if (snowflake == null) return 'غير معروف';
    try {
      final timestamp = ((BigInt.parse(snowflake) >> 22) + BigInt.from(1420070400000)).toInt();
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'غير معروف';
    }
  }
}
