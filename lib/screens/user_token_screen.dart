import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_server_details_screen.dart';
import 'user_server_spam_screen.dart';
import 'package:xcord/screens/colors.dart';

class UserTokenScreen extends StatefulWidget {
  const UserTokenScreen({super.key});

  @override
  State<UserTokenScreen> createState() => _UserTokenScreenState();
}

class _UserTokenScreenState extends State<UserTokenScreen> {
  final _tokenController = TextEditingController();
  bool _isLoading = false;
  bool _isConnected = false;
  List<Map<String, dynamic>> _guilds = [];
  String? _userId;
  bool _obscureToken = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSavedToken();
  }

  Future<void> _loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('discord_user_token');
    if (savedToken != null) {
      _tokenController.text = savedToken;
      _connectToDiscord(savedToken);
    }
  }

  Future<void> _connectToDiscord(String token) async {
    if (token.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى إدخال التوكن أولاً';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // التحقق من صحة التوكن والحصول على معلومات المستخدم
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/users/@me'),
        headers: {'Authorization': token},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _userId = userData['id'];

        // الحصول على قائمة السيرفرات
        final guildsResponse = await http.get(
          Uri.parse('https://discord.com/api/v10/users/@me/guilds'),
          headers: {'Authorization': token},
        );

        if (guildsResponse.statusCode == 200) {
          _guilds = List<Map<String, dynamic>>.from(json.decode(guildsResponse.body));
          
          // حفظ التوكن
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('discord_user_token', token);

          setState(() {
            _isConnected = true;
            _isLoading = false;
          });
        } else {
          throw Exception('فشل في الحصول على السيرفرات');
        }
      } else {
        throw Exception('توكن غير صالح');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
        _errorMessage = 'خطأ في الاتصال: ${e.toString()}';
      });
    }
  }

  void _logout() async {
    // حذف التوكن المحفوظ
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('discord_user_token');
    
    // إعادة تعيين حالة الشاشة
    setState(() {
      _isConnected = false;
      _guilds = [];
      _userId = null;
      _tokenController.clear();
    });
    
    if (mounted) {
      _showSnackBar('تم تسجيل الخروج بنجاح');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'إدخال التوكن',
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_isConnected)
            PopupMenuButton<String>(
              color: AppColors.cardBackground,
              icon: Icon(
                Icons.more_vert,
                color: AppColors.textPrimary,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'change_token',
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'استخدام توكن مختلف',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تحديث القائمة',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'change_token') {
                  _logout();
                } else if (value == 'refresh') {
                  _connectToDiscord(_tokenController.text);
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isConnected
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'السيرفرات المتاحة',
                    style: GoogleFonts.cairo(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.accent,
                            ),
                          )
                        : _guilds.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.discord,
                                      color: AppColors.textSecondary,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'لا توجد سيرفرات متاحة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'يجب أن تكون عضو في سيرفرات ديسكورد',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _guilds.length,
                                itemBuilder: (context, index) {
                                  final guild = _guilds[index];
                                  final iconHash = guild['icon'];
                                  final iconUrl = iconHash != null
                                      ? 'https://cdn.discordapp.com/icons/${guild['id']}/$iconHash.png'
                                      : null;

                                  return Card(
                                    color: AppColors.cardBackground,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          iconUrl != null
                                              ? CircleAvatar(
                                                  radius: 24,
                                                  backgroundImage: NetworkImage(iconUrl),
                                                )
                                              : CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: AppColors.divider,
                                                  child: const Icon(
                                                    Icons.discord,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  guild['name'],
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      guild['owner'] == true
                                                          ? Icons.star
                                                          : Icons.person,
                                                      color: guild['owner'] == true
                                                          ? const Color(0xFFFFC107)
                                                          : AppColors.textSecondary,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      guild['owner'] == true ? 'مالك السيرفر' : 'عضو',
                                                      style: TextStyle(
                                                        color: guild['owner'] == true
                                                            ? const Color(0xFFFFC107)
                                                            : AppColors.textSecondary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              )
            : _buildTokenInput(),
      ),
    );
  }

  Widget _buildTokenInput() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.discord,
                size: 80,
                color: AppColors.accent,
              ),
              const SizedBox(height: 24),
              Text(
                'توكن المستخدم',
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'أدخل توكن المستخدم للاتصال ',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.divider,
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _tokenController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  obscureText: _obscureToken,
                  decoration: InputDecoration(
                    hintText: 'أدخل توكن المستخدم',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    contentPadding: const EdgeInsets.all(16),
                    border: InputBorder.none,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureToken = !_obscureToken;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final token = _tokenController.text.trim();
                          if (token.isNotEmpty) {
                            _connectToDiscord(token);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: AppColors.buttonDisabled,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: AppColors.textPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'اتصال',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 