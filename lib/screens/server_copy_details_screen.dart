import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:xcord/screens/colors.dart';

class ServerCopyDetailsScreen extends StatefulWidget {
  final String serverId;
  final String token;
  final Map<String, dynamic> basicInfo;

  const ServerCopyDetailsScreen({
    super.key,
    required this.serverId,
    required this.token,
    required this.basicInfo,
  });

  @override
  State<ServerCopyDetailsScreen> createState() => _ServerCopyDetailsScreenState();
}

class _ServerCopyDetailsScreenState extends State<ServerCopyDetailsScreen> {
  bool _isLoading = true;
  bool _isCopying = false;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _textChannels = [];
  List<Map<String, dynamic>> _voiceChannels = [];
  List<Map<String, dynamic>> _roles = [];
  String _status = '';
  List<String> _logs = [];
  String _targetGuildId = '';

  @override
  void initState() {
    super.initState();
    
    // إضافة تأخير بسيط لضمان تحميل الشاشة قبل بدء العمليات
    Future.delayed(Duration.zero, () {
      _fetchSourceServerDetails();
    });
  }

  Future<void> _fetchSourceServerDetails() async {
    try {
      // جلب القنوات
      await _fetchChannels();

      // جلب الرتب
      final rolesResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/roles'),
        headers: {'Authorization': widget.token},
      );

      if (rolesResponse.statusCode == 200) {
        final List<dynamic> roles = json.decode(rolesResponse.body);
        setState(() {
          _roles = roles.cast<Map<String, dynamic>>();
        });
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

  Future<void> _fetchChannels() async {
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/channels'),
        headers: {'Authorization': widget.token},
      );

      if (response.statusCode == 200) {
        final channels = json.decode(response.body) as List;
        
        // تصنيف القنوات
        _categories = [];
        _textChannels = [];
        _voiceChannels = [];
        
        // أولاً: استخراج الكاتيجوريز
        for (var channel in channels) {
          if (channel['type'] == 4) { // نوع 4 هو كاتيجوري
            _categories.add(channel);
          }
        }
        
        // ثانياً: تصنيف القنوات النصية والصوتية
        for (var channel in channels) {
          if (channel['type'] == 0 || channel['type'] == 5 || channel['type'] == 15) {
            // أنواع 0 (نصية)، 5 (إعلانات)، 15 (منتدى)
            _textChannels.add(channel);
          } else if (channel['type'] == 2 || channel['type'] == 13) {
            // أنواع 2 (صوتية)، 13 (مسرح)
            _voiceChannels.add(channel);
          }
        }
        
        // ترتيب الكاتيجوريز حسب الموقع
        _categories.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
        
        setState(() {});
      } else {
        throw Exception('فشل في جلب القنوات: ${response.statusCode}');
      }
    } catch (e) {
      print('خطأ في جلب القنوات: ${e.toString()}');
      throw Exception('فشل في جلب القنوات: ${e.toString()}');
    }
  }

  Future<void> _startCopyProcess(String targetGuildId) async {
    setState(() {
      _isLoading = true;
      _targetGuildId = targetGuildId;
      _status = 'بدء عملية النسخ...';
      _logs.clear(); // مسح السجلات السابقة
    });
    
    try {
      // إضافة تأخير بسيط لتحسين تجربة المستخدم
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 1. تنظيف السيرفر الهدف
      _addLog('🔄 تنظيف السيرفر الهدف...');
      await _cleanGuild(targetGuildId);
      
      // 2. نسخ الرتب
      _addLog('🔄 نسخ الرتب...');
      final roleMap = await _copyRoles(targetGuildId);
      
      // 3. نسخ القنوات والكاتيجوريز
      _addLog('🔄 نسخ القنوات والكاتيجوريز...');
      await _copyChannels(targetGuildId, roleMap);
      
      setState(() {
        _isLoading = false;
        _status = 'تم نسخ السيرفر بنجاح!';
      });
      
      _addLog('✅ تم نسخ السيرفر بنجاح!');
      
      // عرض رسالة نجاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نسخ السيرفر بنجاح!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'حدث خطأ أثناء النسخ';
      });
      
      _addLog('❌ فشل في عملية النسخ: ${e.toString()}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadAvailableGuilds() async {
    final response = await http.get(
      Uri.parse('https://discord.com/api/v10/users/@me/guilds'),
      headers: {'Authorization': widget.token},
    );

    if (response.statusCode == 200) {
      final List<dynamic> guilds = json.decode(response.body);
      
      // فلترة السيرفرات التي يملكها المستخدم أو لديه صلاحيات إدارية فيها
      // واستبعاد السيرفر المصدر
      return guilds
          .where((guild) => 
              guild['id'] != widget.serverId && // استبعاد السيرفر المصدر
              (
                guild['owner'] == true || // المالك
                (int.parse(guild['permissions']) & 0x8) != 0 || // ADMINISTRATOR
                (int.parse(guild['permissions']) & 0x20) != 0 // MANAGE_GUILD
              )
          )
          .map((g) => g as Map<String, dynamic>)
          .toList();
    }
    
    throw Exception('فشل في تحميل السيرفرات: ${response.statusCode}');
  }

  Future<void> _cleanGuild(String guildId) async {
    setState(() => _status = 'تنظيف السيرفر الهدف...');
    
    try {
      // 1. حذف جميع القنوات
      final channelsResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels'),
        headers: {'Authorization': widget.token},
      );

      if (channelsResponse.statusCode == 200) {
        final channels = json.decode(channelsResponse.body) as List;
        
        // ترتيب القنوات: أولاً القنوات العادية، ثم الكاتيجوريز
        // هذا مهم لأن القنوات داخل الكاتيجوريز يجب حذفها قبل الكاتيجوريز نفسها
        final sortedChannels = List<Map<String, dynamic>>.from(channels);
        sortedChannels.sort((a, b) {
          // الكاتيجوريز (نوع 4) تأتي في النهاية
          if (a['type'] == 4 && b['type'] != 4) return 1;
          if (a['type'] != 4 && b['type'] == 4) return -1;
          return 0;
        });
        
        for (var channel in sortedChannels) {
          try {
            _addLog('🗑️ حذف قناة: ${channel['name']}');
            
            final response = await http.delete(
              Uri.parse('https://discord.com/api/v10/channels/${channel['id']}'),
              headers: {'Authorization': widget.token},
            );
            
            if (response.statusCode == 200 || response.statusCode == 204) {
              _addLog('✅ تم حذف قناة: ${channel['name']}');
            } else {
              _addLog('⚠️ تحذير عند حذف قناة: ${channel['name']} - ${response.statusCode}');
            }
            
            await Future.delayed(const Duration(milliseconds: 300));
          } catch (e) {
            _addLog('❌ خطأ في حذف القناة: ${channel['name']} - ${e.toString()}');
          }
        }
      }

      // 2. حذف جميع الرتب (ما عدا @everyone)
      final rolesResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/$guildId/roles'),
        headers: {'Authorization': widget.token},
      );

      if (rolesResponse.statusCode == 200) {
        final roles = json.decode(rolesResponse.body) as List;
        
        // ترتيب الرتب من الأدنى إلى الأعلى في الترتيب
        // هذا مهم لأن الرتب العليا قد تكون مطلوبة لحذف الرتب الأدنى
        final sortedRoles = List<Map<String, dynamic>>.from(roles);
        sortedRoles.sort((a, b) => (b['position'] ?? 0).compareTo(a['position'] ?? 0));
        
        for (var role in sortedRoles) {
          if (role['name'] != '@everyone') {
            try {
              _addLog('🗑️ حذف رتبة: ${role['name']}');
              
              final response = await http.delete(
                Uri.parse('https://discord.com/api/v10/guilds/$guildId/roles/${role['id']}'),
                headers: {'Authorization': widget.token},
              );
              
              if (response.statusCode == 204) {
                _addLog('✅ تم حذف رتبة: ${role['name']}');
              } else {
                _addLog('⚠️ تحذير عند حذف رتبة: ${role['name']} - ${response.statusCode}');
              }
              
              await Future.delayed(const Duration(milliseconds: 300));
            } catch (e) {
              _addLog('❌ خطأ في حذف الرتبة: ${role['name']} - ${e.toString()}');
            }
          }
        }
      }
      
      _addLog('✅ تم تنظيف السيرفر الهدف بنجاح');
      return;
    } catch (e) {
      _addLog('❌ خطأ عام في تنظيف السيرفر: ${e.toString()}');
      throw Exception('فشل في تنظيف السيرفر: ${e.toString()}');
    }
  }

  Future<Map<String, String>> _copyRoles(String guildId) async {
    setState(() => _status = 'جاري نسخ الرتب...');
    Map<String, String> roleMap = {};
    
    try {
      // ترتيب الرتب من الأدنى إلى الأعلى في الترتيب
      // هذا مهم لإنشاء الرتب بالترتيب الصحيح
      final sortedRoles = List<Map<String, dynamic>>.from(_roles);
      sortedRoles.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
      
      for (var role in sortedRoles) {
        if (role['name'] != '@everyone') {
          try {
            _addLog('🔄 إنشاء رتبة: ${role['name']}');
            
            // تحويل لون الرتبة إلى صيغة صحيحة
            final color = role['color'] ?? 0;
            
            final response = await http.post(
              Uri.parse('https://discord.com/api/v10/guilds/$guildId/roles'),
              headers: {
                'Authorization': widget.token,
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'name': role['name'],
                'permissions': role['permissions'],
                'color': color,
                'hoist': role['hoist'] ?? false,
                'mentionable': role['mentionable'] ?? false,
                'icon': role['icon'],
                'unicode_emoji': role['unicode_emoji'],
              }),
            );

            if (response.statusCode == 200 || response.statusCode == 201) {
              final newRole = json.decode(response.body);
              roleMap[role['id']] = newRole['id'];
              _addLog('✅ تم إنشاء رتبة: ${role['name']}');
            } else {
              _addLog('❌ فشل في إنشاء الرتبة: ${role['name']} - ${response.statusCode}');
            }
            
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            _addLog('❌ خطأ في إنشاء الرتبة: ${role['name']} - ${e.toString()}');
          }
        }
      }

      // تحديث مواقع الرتب بعد إنشائها جميعاً
      await _updateRolePositions(guildId, roleMap);
      
      return roleMap;
    } catch (e) {
      _addLog('❌ خطأ عام في نسخ الرتب: ${e.toString()}');
      throw Exception('فشل في نسخ الرتب: ${e.toString()}');
    }
  }

  Future<void> _verifyRoles(String guildId, Map<String, String> roleMap) async {
    final response = await http.get(
      Uri.parse('https://discord.com/api/v10/guilds/$guildId/roles'),
      headers: {'Authorization': widget.token},
    );

    if (response.statusCode == 200) {
      final currentRoles = json.decode(response.body) as List;
      final createdRoleIds = roleMap.values.toSet();
      
      // تحقق من الرتب المفقودة
      for (var originalRole in _roles.where((r) => r['name'] != '@everyone')) {
        if (!roleMap.containsKey(originalRole['id'])) {
          try {
            final response = await http.post(
              Uri.parse('https://discord.com/api/v10/guilds/$guildId/roles'),
              headers: {
                'Authorization': widget.token,
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'name': originalRole['name'],
                'permissions': originalRole['permissions'],
                'color': originalRole['color'],
                'hoist': originalRole['hoist'],
                'mentionable': originalRole['mentionable'],
              }),
            );

            if (response.statusCode == 200) {
              final newRole = json.decode(response.body);
              roleMap[originalRole['id']] = newRole['id'];
            }
            
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            print('تحقق - فشل في إنشاء الرتبة: ${originalRole['name']}');
          }
        }
      }
    }
  }

  Future<void> _copyChannels(String guildId, Map<String, String> roleMap) async {
    try {
      // 1. تنظيم البيانات وترتيبها
      setState(() => _status = 'تنظيم بيانات القنوات والكاتيجوريز...');
      
      // ترتيب الكاتيجوريز حسب الموقع
      _categories.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
      
      // ترتيب القنوات داخل كل كاتيجوري
      final Map<String, List<Map<String, dynamic>>> channelsByCategory = {};
      
      // تجميع القنوات النصية والصوتية حسب الكاتيجوري
      for (var channel in [..._textChannels, ..._voiceChannels]) {
        final parentId = channel['parent_id'];
        if (parentId != null) {
          channelsByCategory[parentId] = channelsByCategory[parentId] ?? [];
          channelsByCategory[parentId]!.add(channel);
        }
      }
      
      // ترتيب القنوات داخل كل كاتيجوري
      for (var categoryId in channelsByCategory.keys) {
        channelsByCategory[categoryId]!.sort((a, b) => 
          (a['position'] ?? 0).compareTo(b['position'] ?? 0));
      }
      
      // 2. إنشاء الكاتيجوريز أولاً
      setState(() => _status = 'إنشاء الكاتيجوريز...');
      final categoryMap = <String, String>{};
      
      for (var category in _categories) {
        try {
          final response = await http.post(
            Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels'),
            headers: {
              'Authorization': widget.token,
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'name': category['name'],
              'type': 4,
              'position': category['position'],
              'permission_overwrites': _updatePermissionOverwrites(
                category['permission_overwrites'] ?? [], 
                roleMap
              ),
            }),
          );
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            final newCategory = json.decode(response.body);
            categoryMap[category['id']] = newCategory['id'];
            _addLog('✅ تم إنشاء كاتيجوري: ${category['name']}');
          } else {
            _addLog('❌ فشل في إنشاء كاتيجوري: ${category['name']} - ${response.statusCode}');
          }
          
          // تأخير بسيط بين الطلبات
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _addLog('❌ خطأ في إنشاء كاتيجوري ${category['name']}: ${e.toString()}');
        }
      }
      
      // 3. إنشاء القنوات داخل الكاتيجوريز
      setState(() => _status = 'إنشاء القنوات داخل الكاتيجوريز...');
      
      // إنشاء القنوات لكل كاتيجوري بالترتيب
      for (var category in _categories) {
        final categoryId = category['id'];
        final newCategoryId = categoryMap[categoryId];
        
        if (newCategoryId == null) {
          _addLog('⚠️ تخطي القنوات في كاتيجوري ${category['name']} لأنه لم يتم إنشاؤه');
          continue;
        }
        
        final channels = channelsByCategory[categoryId] ?? [];
        
        // ترتيب القنوات حسب الموقع
        channels.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
        
        for (var channel in channels) {
          try {
            final isText = channel['type'] == 0;
            final isVoice = channel['type'] == 2;
            final isAnnouncement = channel['type'] == 5;
            final isStage = channel['type'] == 13;
            final isForum = channel['type'] == 15;
            
            int channelType;
            if (isText) channelType = 0;
            else if (isVoice) channelType = 2;
            else if (isAnnouncement) channelType = 5;
            else if (isStage) channelType = 13;
            else if (isForum) channelType = 15;
            else continue; // تخطي أنواع القنوات غير المدعومة
            
            final response = await http.post(
              Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels'),
              headers: {
                'Authorization': widget.token,
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'name': channel['name'],
                'type': channelType,
                'topic': channel['topic'],
                'rate_limit_per_user': channel['rate_limit_per_user'],
                'position': channel['position'],
                'parent_id': newCategoryId,
                'nsfw': channel['nsfw'] ?? false,
                'permission_overwrites': _updatePermissionOverwrites(
                  channel['permission_overwrites'] ?? [], 
                  roleMap
                ),
                if (isVoice || isStage) 'bitrate': channel['bitrate'] ?? 64000,
                if (isVoice || isStage) 'user_limit': channel['user_limit'] ?? 0,
              }),
            );
            
            if (response.statusCode == 200 || response.statusCode == 201) {
              _addLog('✅ تم إنشاء قناة: ${channel['name']} في ${category['name']}');
            } else {
              _addLog('❌ فشل في إنشاء قناة: ${channel['name']} - ${response.statusCode}');
            }
            
            // تأخير بسيط بين الطلبات
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            _addLog('❌ خطأ في إنشاء قناة ${channel['name']}: ${e.toString()}');
          }
        }
      }
      
      // 4. إنشاء القنوات التي ليست في أي كاتيجوري
      setState(() => _status = 'إنشاء القنوات المستقلة...');
      
      final independentChannels = [..._textChannels, ..._voiceChannels]
        .where((channel) => channel['parent_id'] == null)
        .toList();
      
      independentChannels.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
      
      for (var channel in independentChannels) {
        try {
          final isText = channel['type'] == 0;
          final isVoice = channel['type'] == 2;
          final isAnnouncement = channel['type'] == 5;
          final isStage = channel['type'] == 13;
          final isForum = channel['type'] == 15;
          
          int channelType;
          if (isText) channelType = 0;
          else if (isVoice) channelType = 2;
          else if (isAnnouncement) channelType = 5;
          else if (isStage) channelType = 13;
          else if (isForum) channelType = 15;
          else continue; // تخطي أنواع القنوات غير المدعومة
          
          final response = await http.post(
            Uri.parse('https://discord.com/api/v10/guilds/$guildId/channels'),
            headers: {
              'Authorization': widget.token,
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'name': channel['name'],
              'type': channelType,
              'topic': channel['topic'],
              'rate_limit_per_user': channel['rate_limit_per_user'],
              'position': channel['position'],
              'nsfw': channel['nsfw'] ?? false,
              'permission_overwrites': _updatePermissionOverwrites(
                channel['permission_overwrites'] ?? [], 
                roleMap
              ),
              if (isVoice || isStage) 'bitrate': channel['bitrate'] ?? 64000,
              if (isVoice || isStage) 'user_limit': channel['user_limit'] ?? 0,
            }),
          );
          
          if (response.statusCode == 200 || response.statusCode == 201) {
            _addLog('✅ تم إنشاء قناة مستقلة: ${channel['name']}');
          } else {
            _addLog('❌ فشل في إنشاء قناة مستقلة: ${channel['name']} - ${response.statusCode}');
          }
          
          // تأخير بسيط بين الطلبات
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          _addLog('❌ خطأ في إنشاء قناة مستقلة ${channel['name']}: ${e.toString()}');
        }
      }
      
      setState(() => _status = 'تم نسخ السيرفر بنجاح!');
    } catch (e) {
      _addLog('❌ خطأ عام في نسخ القنوات: ${e.toString()}');
      throw Exception('فشل في عملية النسخ: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> _updatePermissionOverwrites(
    List<dynamic> overwrites, 
    Map<String, String> roleMap
  ) {
    final result = <Map<String, dynamic>>[];
    
    for (var overwrite in overwrites) {
      final type = overwrite['type'];
      final id = overwrite['id'];
      
      // إذا كان النوع 0 (رتبة)، استبدل المعرف بالمعرف الجديد
      if (type == 0 && roleMap.containsKey(id)) {
        result.add({
          'id': roleMap[id]!,
          'type': type,
          'allow': overwrite['allow'],
          'deny': overwrite['deny'],
        });
      } 
      // إذا كان النوع 1 (مستخدم)، احتفظ به كما هو
      else if (type == 1) {
        result.add({
          'id': id,
          'type': type,
          'allow': overwrite['allow'],
          'deny': overwrite['deny'],
        });
      }
      // إذا كان رتبة @everyone
      else if (id == widget.serverId) {
        result.add({
          'id': widget.serverId, // استخدم معرف السيرفر الهدف
          'type': type,
          'allow': overwrite['allow'],
          'deny': overwrite['deny'],
        });
      }
    }
    
    return result;
  }

  Future<void> _updateRolePositions(String guildId, Map<String, String> roleMap) async {
    try {
      _addLog('🔄 تحديث مواقع الرتب...');
      
      // ترتيب الرتب حسب الموقع
      final sortedRoles = List<Map<String, dynamic>>.from(_roles);
      sortedRoles.sort((a, b) => (a['position'] ?? 0).compareTo(b['position'] ?? 0));
      
      // إنشاء قائمة بمواقع الرتب الجديدة
      final List<Map<String, dynamic>> positions = [];
      
      for (var role in sortedRoles) {
        if (role['name'] != '@everyone' && roleMap.containsKey(role['id'])) {
          positions.add({
            'id': roleMap[role['id']]!,
            'position': role['position'] ?? 1,
          });
        }
      }
      
      if (positions.isNotEmpty) {
        final response = await http.patch(
          Uri.parse('https://discord.com/api/v10/guilds/$guildId/roles'),
          headers: {
            'Authorization': widget.token,
            'Content-Type': 'application/json',
          },
          body: json.encode(positions),
        );
        
        if (response.statusCode == 200) {
          _addLog('✅ تم تحديث مواقع الرتب بنجاح');
        } else {
          _addLog('⚠️ تحذير: فشل في تحديث مواقع الرتب - ${response.statusCode}');
        }
      }
    } catch (e) {
      _addLog('⚠️ تحذير: خطأ في تحديث مواقع الرتب - ${e.toString()}');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
    
    // طباعة الرسالة في وحدة التحكم للتصحيح
    print(message);
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.accent,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _targetGuildId.isEmpty ? Icons.info_outline : Icons.check_circle,
                    color: _targetGuildId.isEmpty ? AppColors.accent : AppColors.success,
                    size: 24,
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _status.isEmpty
                    ? 'اختر سيرفر الهدف لبدء عملية النسخ'
                    : _status,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          title,
          style: GoogleFonts.cairo(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
            ),
            child: Text(
              'حسناً',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'نسخ سيرفر',
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات السيرفر المصدر
            Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // صورة السيرفر
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: widget.basicInfo['icon'] != null
                          ? NetworkImage(
                              'https://cdn.discordapp.com/icons/${widget.basicInfo['id']}/${widget.basicInfo['icon']}.png',
                            )
                          : null,
                      backgroundColor: AppColors.divider,
                      child: widget.basicInfo['icon'] == null
                          ? const Icon(Icons.discord, color: AppColors.textPrimary, size: 30)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // معلومات السيرفر
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.basicInfo['name'] ?? 'سيرفر غير معروف',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'المصدر: ${_textChannels.length} قناة نصية، ${_voiceChannels.length} قناة صوتية، ${_roles.length} رتبة',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // حالة النسخ
            Text(
              'حالة النسخ:',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // بطاقة الحالة
            _buildStatusCard(),
            
            const SizedBox(height: 16),
            
            // إحصائيات
            if (!_isLoading && _categories.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('الكاتيجوريز', _categories.length, Icons.category),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard('القنوات النصية', _textChannels.length, Icons.chat),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard('القنوات الصوتية', _voiceChannels.length, Icons.mic),
                  ),
                ],
              ),
            
            if (!_isLoading && _categories.isNotEmpty)
              const SizedBox(height: 16),
            
            // سجل العمليات
            Expanded(
              child: _buildLogsList(),
            ),
            
            const SizedBox(height: 16),
            
            // زر بدء النسخ
            _buildStartCopyButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'سجل العمليات:',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_logs.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _logs.clear();
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    label: Text(
                      'مسح السجل',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          color: AppColors.textSecondary.withOpacity(0.5),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد عمليات حتى الآن',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final log = _logs[_logs.length - 1 - index];
                      final isError = log.contains('❌');
                      final isWarning = log.contains('⚠️');
                      final isSuccess = log.contains('✅');
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log,
                                style: TextStyle(
                                  color: isError
                                      ? AppColors.error
                                      : isWarning
                                          ? AppColors.warning
                                          : isSuccess
                                              ? AppColors.success
                                              : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartCopyButton() {
    if (_targetGuildId.isNotEmpty) {
      return const SizedBox.shrink(); // تم بدء النسخ بالفعل
    }
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _fetchAvailableGuilds,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          disabledBackgroundColor: AppColors.buttonDisabled,
        ),
        child: Text(
          'بدء النسخ',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Future<void> _fetchAvailableGuilds() async {
    try {
      setState(() {
        _isLoading = true;
        _status = 'جاري تحميل السيرفرات المتاحة...';
      });
      
      final availableGuilds = await _loadAvailableGuilds();
      
      if (!mounted) return;
      
      // عرض مربع حوار لاختيار السيرفر الهدف
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'اختر السيرفر الهدف',
            style: GoogleFonts.cairo(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: availableGuilds.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.warning,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا توجد سيرفرات متاحة للنسخ إليها',
                          style: GoogleFonts.cairo(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'يجب أن تكون مالك السيرفر أو لديك صلاحيات إدارية',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableGuilds.length,
                    itemBuilder: (context, index) {
                      final guild = availableGuilds[index];
                      final iconHash = guild['icon'];
                      final iconUrl = iconHash != null
                          ? 'https://cdn.discordapp.com/icons/${guild['id']}/$iconHash.png'
                          : null;
                      
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        tileColor: Colors.transparent,
                        leading: iconUrl != null
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(iconUrl),
                              )
                            : CircleAvatar(
                                backgroundColor: AppColors.divider,
                                child: const Icon(
                                  Icons.discord,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                        title: Text(
                          guild['name'],
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          guild['owner'] == true ? 'مالك السيرفر' : 'عضو',
                          style: TextStyle(
                            color: guild['owner'] == true
                                ? const Color(0xFFFFC107)
                                : AppColors.textSecondary,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _startCopyProcess(guild['id']);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isLoading = false;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorDialog(
        'خطأ في تحميل السيرفرات',
        'حدث خطأ أثناء تحميل السيرفرات المتاحة: ${e.toString()}',
      );
    }
  }
} 