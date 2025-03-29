import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:isolate';
import 'package:xcord/screens/colors.dart'; // إضافة استيراد ملف الألوان

class UserServerSpamScreen extends StatefulWidget {
  final String serverId;
  final String token;
  final Map<String, dynamic> serverInfo;

  const UserServerSpamScreen({
    super.key,
    required this.serverId,
    required this.token,
    required this.serverInfo,
  });

  @override
  State<UserServerSpamScreen> createState() => _UserServerSpamScreenState();
}

class _UserServerSpamScreenState extends State<UserServerSpamScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _channels = [];
  final _messageController = TextEditingController();
  final _countController = TextEditingController(text: '10');
  String _status = '';
  int _sentCount = 0;
  bool _isSending = false;
  
  // إضافة متغير للتحكم في عدد الطلبات المتزامنة
  final int _maxConcurrentRequests = 20;
  final int _maxMessages = 20; // إضافة ثابت للحد الأقصى للرسائل
  
  // إضافة متغير للتحكم في إلغاء العملية
  bool _cancelRequested = false;
  
  // إضافة متغير لتخزين القناة المحددة
  Map<String, dynamic>? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }
  
  @override
  void dispose() {
    _cancelRequested = true;
    super.dispose();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/guilds/${widget.serverId}/channels'),
        headers: {'Authorization': widget.token},
      );

      if (response.statusCode == 200) {
        final List<dynamic> allChannels = json.decode(response.body);
        
        // فلترة القنوات النصية فقط (type = 0)
        _channels = allChannels
            .where((channel) => channel['type'] == 0)
            .map((channel) => channel as Map<String, dynamic>)
            .toList();
        
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _status = 'فشل في تحميل القنوات: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'خطأ: ${e.toString()}';
      });
    }
  }

  Future<void> _sendMessages() async {
    if (_selectedChannel == null) {
      setState(() {
        _status = 'الرجاء اختيار قناة أولاً';
      });
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(() {
        _status = 'الرجاء إدخال رسالة';
      });
      return;
    }

    final count = int.tryParse(_countController.text) ?? 10;
    if (count <= 0 || count > _maxMessages) {
      setState(() {
        _status = 'عدد الرسائل يجب أن يكون بين 1 و $_maxMessages';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _sentCount = 0;
      _status = 'جاري إرسال الرسائل...';
      _cancelRequested = false;
    });

    final channelId = _selectedChannel!['id'];
    
    // استخدام مجموعة من الطلبات المتزامنة مع التحكم في العدد
    final semaphore = Semaphore(_maxConcurrentRequests);
    
    try {
      final futures = <Future>[];
      
      for (int i = 0; i < count && !_cancelRequested; i++) {
        final future = semaphore.acquire().then((_) async {
          if (_cancelRequested) return;
          
          try {
            final response = await http.post(
              Uri.parse('https://discord.com/api/v10/channels/$channelId/messages'),
              headers: {
                'Authorization': widget.token,
                'Content-Type': 'application/json',
              },
              body: json.encode({'content': '$message (${i + 1}/$count)'}),
            );
            
            if (!mounted || _cancelRequested) return;
            
            setState(() {
              if (response.statusCode == 200 || response.statusCode == 201) {
                _sentCount++;
                _status = 'تم إرسال $_sentCount من $count رسالة';
              } else {
                _status = 'خطأ في الإرسال: ${response.statusCode}';
              }
            });
          } catch (e) {
            if (!mounted || _cancelRequested) return;
            setState(() {
              _status = 'خطأ: ${e.toString()}';
            });
          } finally {
            semaphore.release();
          }
        });
        
        futures.add(future);
        
        // إضافة تأخير بسيط بين الرسائل لتجنب التقييد
        await Future.delayed(const Duration(milliseconds: 300));
      }
      
      await Future.wait(futures);
      
      if (mounted) {
        setState(() {
          _isSending = false;
          if (_cancelRequested) {
            _status = 'تم إلغاء العملية. تم إرسال $_sentCount من $count رسالة';
          } else {
            _status = 'اكتمل الإرسال. تم إرسال $_sentCount من $count رسالة';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _status = 'خطأ: ${e.toString()}';
        });
      }
    }
  }

  void _cancelSending() {
    setState(() {
      _cancelRequested = true;
      _status = 'جاري إلغاء العملية...';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'إرسال سبام',
          style: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اختر القناة',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    dropdownColor: AppColors.cardBackground,
                                    value: _selectedChannel?['id'],
                                    hint: Text(
                                      'اختر قناة',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                    style: TextStyle(color: AppColors.textPrimary),
                                    icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                    items: _channels.map((channel) {
                                      return DropdownMenuItem<String>(
                                        value: channel['id'],
                                        child: Text(
                                          '#${channel['name']}',
                                          style: TextStyle(color: AppColors.textPrimary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedChannel = _channels.firstWhere(
                                          (channel) => channel['id'] == value,
                                        );
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الرسالة',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _messageController,
                                style: TextStyle(color: AppColors.textPrimary),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  hintText: 'أدخل الرسالة هنا...',
                                  hintStyle: TextStyle(color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppColors.divider),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppColors.divider),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppColors.accent),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: AppColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'عدد الرسائل',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _countController,
                                style: TextStyle(color: AppColors.textPrimary),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: 'أدخل عدد الرسائل (1-$_maxMessages)',
                                  hintStyle: TextStyle(color: AppColors.textSecondary),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppColors.divider),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppColors.divider),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: AppColors.accent),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSending ? null : _sendMessages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          disabledBackgroundColor: AppColors.buttonDisabled,
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'إرسال الرسائل',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_status.isNotEmpty && !_isSending)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.accent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
          ),
          if (_isSending)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  color: AppColors.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _status,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _cancelSending,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'إلغاء',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// فئة مساعدة للتحكم في عدد الطلبات المتزامنة
class Semaphore {
  final int _maxCount;
  int _currentCount = 0;
  final List<Completer<void>> _waiters = [];

  Semaphore(this._maxCount);

  Future<void> acquire() async {
    if (_currentCount < _maxCount) {
      _currentCount++;
      return Future.value();
    }
    
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final completer = _waiters.removeAt(0);
      completer.complete();
    } else {
      _currentCount--;
    }
  }
}