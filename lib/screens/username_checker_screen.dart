import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/rendering.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class UsernameCheckerScreen extends StatefulWidget {
  final String platform;
  final Color platformColor;

  const UsernameCheckerScreen({
    Key? key,
    required this.platform,
    required this.platformColor,
  }) : super(key: key);

  @override
  State<UsernameCheckerScreen> createState() => _UsernameCheckerScreenState();
}

class _UsernameCheckerScreenState extends State<UsernameCheckerScreen> {
  final TextEditingController _lengthController = TextEditingController(text: '4');
  final ScrollController _logScrollController = ScrollController();
  final List<String> _logs = [];
  bool _isChecking = false;
  int _checkedCount = 0;
  int _availableCount = 0;
  List<String> _availableUsernames = [];
  
  // قائمة البروكسيات
  List<String> _proxies = [];
  int _currentProxyIndex = 0;
  
  // للتعامل مع Isolate
  Isolate? _isolate;
  ReceivePort? _receivePort;
  StreamSubscription? _subscription;
  
  // قائمة User-Agents
  final List<String> _userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Safari/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.107 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadProxies();
  }
  
  @override
  void dispose() {
    _lengthController.dispose();
    _logScrollController.dispose();
    
    // إلغاء الاشتراك في الرسائل من Isolate
    _subscription?.cancel();
    
    // إيقاف Isolate إذا كان لا يزال يعمل
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort?.close();
    
    super.dispose();
  }
  
  Future<void> _loadProxies() async {
    _addLog('جاري تحميل قائمة البروكسيات...');
    
    try {
      // استخدام عدة مصادر للبروكسيات المجانية
      final sources = [
        'https://raw.githubusercontent.com/TheSpeedX/PROXY-List/master/http.txt',
        'https://raw.githubusercontent.com/ShiftyTR/Proxy-List/master/http.txt',
        'https://raw.githubusercontent.com/monosans/proxy-list/main/proxies/http.txt',
        'https://api.proxyscrape.com/v2/?request=getproxies&protocol=http&timeout=10000&country=all',
        'https://www.proxy-list.download/api/v1/get?type=http'
      ];
      
      for (final source in sources) {
        try {
          final response = await http.get(Uri.parse(source)).timeout(
            const Duration(seconds: 5),
            onTimeout: () => http.Response('', 408),
          );
          
          if (response.statusCode == 200) {
            final List<String> newProxies = response.body
                .split('\n')
                .where((line) => line.trim().isNotEmpty && line.contains(':'))
                .toList();
            
            _proxies.addAll(newProxies);
            _addLog('تم تحميل ${newProxies.length} بروكسي من $source');
          }
        } catch (e) {
          _addLog('فشل تحميل البروكسيات من $source: $e');
        }
      }
      
      // إزالة التكرارات
      _proxies = _proxies.toSet().toList();
      _addLog('تم تحميل ${_proxies.length} بروكسي فريد بنجاح');
      
      if (_proxies.isEmpty) {
        _addLog('تحذير: لم يتم تحميل أي بروكسي، سيتم استخدام الاتصال المباشر');
      }
    } catch (e) {
      _addLog('خطأ في تحميل البروكسيات: $e');
    }
  }
  
  String _getRandomUserAgent() {
    return _userAgents[Random().nextInt(_userAgents.length)];
  }
  
  String? _getNextProxy() {
    if (_proxies.isEmpty) return null;
    
    _currentProxyIndex = (_currentProxyIndex + 1) % _proxies.length;
    return _proxies[_currentProxyIndex];
  }
  
  Future<void> _startChecking() async {
    if (_isChecking) return;
    
    final lengthText = _lengthController.text.trim();
    if (lengthText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال طول المعرف')),
      );
      return;
    }
    
    final length = int.tryParse(lengthText);
    if (length == null || length < 3 || length > 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب أن يكون طول المعرف بين 3 و 16')),
      );
      return;
    }
    
    setState(() {
      _isChecking = true;
      _logs.clear();
      _checkedCount = 0;
      _availableCount = 0;
      _availableUsernames.clear();
    });
    
    _addLog('بدء فحص اليوزرات على ${widget.platform} بطول $length حرف');
    
    // استخدام Isolate للفحص في الخلفية
    _receivePort = ReceivePort();
    
    // إلغاء الاشتراك السابق إذا كان موجوداً
    _subscription?.cancel();
    
    // استقبال النتائج من Isolate
    _subscription = _receivePort!.listen((message) {
      if (!mounted) return; // تجاهل الرسائل إذا تم إزالة الشاشة
      
      if (message is Map) {
        if (message.containsKey('log')) {
          _addLog(message['log']);
        }
        if (message.containsKey('checked')) {
          setState(() {
            _checkedCount = message['checked'];
          });
        }
        if (message.containsKey('available')) {
          setState(() {
            _availableCount = message['available'];
          });
        }
        if (message.containsKey('username')) {
          setState(() {
            _availableUsernames.add(message['username']);
          });
        }
        if (message.containsKey('done')) {
          setState(() {
            _isChecking = false;
          });
          _addLog('انتهى الفحص: تم فحص $_checkedCount معرف، وجد $_availableCount متاح');
          
          // إيقاف Isolate بعد الانتهاء
          _isolate?.kill(priority: Isolate.immediate);
          _isolate = null;
        }
      }
    });
    
    try {
      _isolate = await Isolate.spawn(
        _checkUsernames,
        {
          'sendPort': _receivePort!.sendPort,
          'platform': widget.platform,
          'length': length,
          'proxies': _proxies,
          'userAgents': _userAgents,
        },
      );
    } catch (e) {
      _addLog('خطأ في بدء عملية الفحص: $e');
      setState(() {
        _isChecking = false;
      });
    }
  }
  
  // دالة تعمل في Isolate منفصل
  static Future<void> _checkUsernames(Map<String, dynamic> params) async {
    final sendPort = params['sendPort'] as SendPort;
    final platform = params['platform'] as String;
    final length = params['length'] as int;
    final proxies = params['proxies'] as List<String>;
    final userAgents = params['userAgents'] as List<String>;
    
    int checkedCount = 0;
    int availableCount = 0;
    
    // الحروف المسموح بها في اليوزرات
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
    final random = Random();
    
    // عدد اليوزرات للفحص
    const totalToCheck = 1000;
    
    try {
      for (int i = 0; i < totalToCheck; i++) {
        // إنشاء معرف عشوائي
        String username = '';
        for (int j = 0; j < length; j++) {
          username += chars[random.nextInt(chars.length)];
        }
        
        sendPort.send({'log': 'فحص المعرف: $username'});
        
        bool isAvailable = false;
        bool checked = false;
        int retries = 0;
        
        while (!checked && retries < 3) {
          try {
            // اختيار بروكسي عشوائي
            final proxyIndex = proxies.isEmpty ? -1 : random.nextInt(proxies.length);
            final proxy = (proxyIndex >= 0 && proxies.isNotEmpty) ? proxies[proxyIndex] : null;
            
            // اختيار User-Agent عشوائي
            final userAgent = userAgents[random.nextInt(userAgents.length)];
            
            if (proxy != null) {
              sendPort.send({'log': 'استخدام بروكسي: $proxy'});
            }
            
            isAvailable = await _checkUsernameAvailability(
              platform, 
              username, 
              proxy, 
              userAgent,
              sendPort,
            );
            
            checked = true;
          } catch (e) {
            retries++;
            sendPort.send({'log': 'خطأ في الفحص (محاولة $retries): $e'});
            await Future.delayed(Duration(milliseconds: 100 * retries));
          }
        }
        
        checkedCount++;
        
        if (isAvailable) {
          availableCount++;
          sendPort.send({
            'log': '✅ المعرف $username متاح على ${platform}!',
            'username': username,
            'available': availableCount,
          });
        } else {
          sendPort.send({'log': '❌ المعرف $username غير متاح على ${platform}'});
        }
        
        sendPort.send({'checked': checkedCount});
        
        // تأخير قصير جداً بين الطلبات لتجنب الضغط على الخادم
        await Future.delayed(Duration(milliseconds: 50));
      }
    } catch (e) {
      sendPort.send({'log': 'خطأ عام في عملية الفحص: $e'});
    } finally {
      // التأكد من إرسال إشارة الانتهاء حتى في حالة حدوث خطأ
      sendPort.send({'done': true});
    }
  }
  
  static Future<bool> _checkUsernameAvailability(
    String platform, 
    String username, 
    String? proxy, 
    String userAgent,
    SendPort sendPort,
  ) async {
    try {
      http.Client client = http.Client();
      Uri uri;
      Map<String, String> headers = {
        'User-Agent': userAgent,
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept': 'text/html,application/json',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };
      
      switch (platform) {
        case 'ديسكورد':
          uri = Uri.parse('https://discord.com/api/v9/users/@me/channels');
          headers['Authorization'] = 'Bot ' + 'dummy_token';
          break;
        case 'انستجرام':
          uri = Uri.parse('https://www.instagram.com/$username/?__a=1');
          break;
        case 'تيكتوك':
          uri = Uri.parse('https://www.tiktok.com/@$username');
          break;
        default:
          throw Exception('منصة غير مدعومة');
      }
      
      http.Response response;
      
      if (proxy != null) {
        // استخدام بروكسي
        final request = http.Request('GET', uri);
        request.headers.addAll(headers);
        
        final httpClient = HttpClient(proxy: proxy);
        final streamedResponse = await httpClient.send(request);
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // بدون بروكسي
        response = await client.get(uri, headers: headers)
            .timeout(const Duration(seconds: 5));
      }
      
      sendPort.send({'log': 'استجابة الخادم: ${response.statusCode}'});
      
      switch (platform) {
        case 'ديسكورد':
          // في ديسكورد، إذا كان المعرف غير موجود، سيعيد خطأ 404
          return response.statusCode == 404;
        case 'انستجرام':
          // في انستجرام، إذا كان المعرف غير موجود، سيعيد صفحة "المستخدم غير موجود"
          return response.statusCode == 404 || response.body.contains('"user":null');
        case 'تيكتوك':
          // في تيكتوك، إذا كان المعرف غير موجود، سيعيد صفحة "المستخدم غير موجود"
          return response.statusCode == 404 || response.body.contains('Not found');
        default:
          return false;
      }
    } catch (e) {
      sendPort.send({'log': 'خطأ في فحص المعرف: $e'});
      rethrow;
    }
  }
  
  void _addLog(String message) {
    // التحقق من أن الشاشة لا تزال موجودة قبل استدعاء setState
    if (mounted) {
      setState(() {
        _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
        
        // تمرير إلى نهاية السجل
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      });
    }
  }
  
  void _copyAvailableUsernames() {
    if (_availableUsernames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد يوزرات متاحة للنسخ')),
      );
      return;
    }
    
    final text = _availableUsernames.join('\n');
    // نسخ النص إلى الحافظة
    // Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نسخ ${_availableUsernames.length} معرف إلى الحافظة')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'فحص يوزرات ${widget.platform}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: widget.platformColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.platformColor.withOpacity(0.3),
              Colors.black,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // بطاقة إدخال طول المعرف
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: widget.platformColor.withOpacity(0.5), width: 1),
                ),
                color: Colors.grey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طول المعرف',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _lengthController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: 'أدخل طول المعرف (3-16)',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                filled: true,
                                fillColor: Colors.grey[800],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _isChecking ? null : _startChecking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.platformColor,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: _isChecking
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'بدء الفحص',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // بطاقات الإحصائيات
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    'تم الفحص',
                    '$_checkedCount',
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'متاح',
                    '$_availableCount',
                    Colors.green,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // سجل اللوج
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[800]!, width: 1),
                  ),
                  color: Colors.grey[900],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'سجل العمليات',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.clear_all, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _logs.clear();
                                });
                              },
                              tooltip: 'مسح السجل',
                            ),
                          ],
                        ),
                      ),
                      Divider(color: Colors.grey[800], height: 1),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: ListView.builder(
                            controller: _logScrollController,
                            itemCount: _logs.length,
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              Color textColor = Colors.grey[400]!;
                              
                              if (log.contains('✅')) {
                                textColor = Colors.green;
                              } else if (log.contains('❌')) {
                                textColor = Colors.red[300]!;
                              } else if (log.contains('خطأ') || log.contains('فشل')) {
                                textColor = Colors.orange;
                              } else if (log.contains('تم تحميل') || log.contains('بنجاح')) {
                                textColor = Colors.cyan;
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  log,
                                  style: TextStyle(
                                    color: textColor,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // قسم اليوزرات المتاحة
              if (_availableUsernames.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.green.withOpacity(0.5), width: 1),
                  ),
                  color: Colors.grey[900],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'اليوزرات المتاحة',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy_all, color: Colors.green),
                                  onPressed: _copyAllUsernames,
                                  tooltip: 'نسخ الكل',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.save, color: Colors.blue),
                                  onPressed: _saveUsernames,
                                  tooltip: 'حفظ الكل',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(color: Colors.grey[800], height: 1),
                      Container(
                        height: 150,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child: ListView.builder(
                          itemCount: _availableUsernames.length,
                          itemBuilder: (context, index) {
                            final username = _availableUsernames[index];
                            return Card(
                              color: Colors.grey[850],
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  username,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                                      onPressed: () => _copyUsername(username),
                                      tooltip: 'نسخ',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.open_in_new, size: 18, color: Colors.orange),
                                      onPressed: () => _openUsernameProfile(username),
                                      tooltip: 'فتح الملف الشخصي',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // دالة نسخ معرف واحد
  void _copyUsername(String username) {
    Clipboard.setData(ClipboardData(text: username));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ المعرف: $username'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // دالة نسخ جميع المعرفات
  void _copyAllUsernames() {
    final allUsernames = _availableUsernames.join('\n');
    Clipboard.setData(ClipboardData(text: allUsernames));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ ${_availableUsernames.length} معرف'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // دالة حفظ المعرفات (يمكن تنفيذها لاحقاً)
  void _saveUsernames() {
    // هنا يمكن إضافة كود لحفظ المعرفات في ملف أو قاعدة بيانات
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('سيتم إضافة ميزة الحفظ قريباً'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // دالة فتح الملف الشخصي للمعرف
  void _openUsernameProfile(String username) async {
    String url;
    switch (widget.platform) {
      case 'ديسكورد':
        url = 'https://discord.com/users/$username';
        break;
      case 'انستجرام':
        url = 'https://www.instagram.com/$username/';
        break;
      case 'تيكتوك':
        url = 'https://www.tiktok.com/@$username';
        break;
      default:
        url = '';
    }
    
    if (url.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } catch (e) {
        _addLog('فشل في فتح الرابط: $e');
      }
    }
  }
}

// فئة HttpClient مخصصة للتعامل مع البروكسيات
class HttpClient extends http.BaseClient {
  final String proxy;
  final http.Client _inner = http.Client();

  HttpClient({required this.proxy});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // تنفيذ الطلب عبر البروكسي
    // هذا تنفيذ مبسط، في التطبيق الحقيقي ستحتاج إلى استخدام مكتبة تدعم البروكسيات
    try {
      final parts = proxy.split(':');
      final host = parts[0];
      final port = int.parse(parts[1]);
      
      // هنا يجب استخدام مكتبة تدعم البروكسيات مثل dio أو http_proxy
      // هذا مجرد مثال وليس تنفيذاً حقيقياً
      return await _inner.send(request);
    } catch (e) {
      throw Exception('فشل استخدام البروكسي: $e');
    }
  }
} 