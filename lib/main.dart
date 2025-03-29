import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'screens/nuke_screen.dart';
import 'screens/user_token_screen.dart';
import 'screens/user_copy_server_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/username_checker_screen.dart';

// ألوان التطبيق الرئيسية
const primaryColor = Color(0xFF9C27B0);
const backgroundColor = Color(0xFF121212);
const surfaceColor = Color(0xFF1E1E1E);
const appBarColor = Color(0xFF1E1E1E);

// تعريف متغير عام للوصول إلى Supabase
final supabase = Supabase.instance.client;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: 'https://rlhvejslfwohwegbndge.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJsaHZlanNsZndvaHdlZ2JuZGdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDMyODU1MjQsImV4cCI6MjA1ODg2MTUyNH0.mS5Iqmfgh03QoIyoft_Isn3UnZriah2u-_fRjFAllkI',
    );
    print("Supabase initialized successfully");
  } catch (e) {
    print("Error initializing Supabase: $e");
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const XCordApp());
}

class XCordApp extends StatelessWidget {
  const XCordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XCORD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: primaryColor,
          background: backgroundColor,
          surface: surfaceColor,
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.cairoTextTheme(
          Theme.of(context).textTheme.apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
        ),
      ),
      home: const UpdateCheckScreen(),
    );
  }
}

// شاشة التحقق من التحديثات
class UpdateCheckScreen extends StatefulWidget {
  const UpdateCheckScreen({super.key});

  @override
  State<UpdateCheckScreen> createState() => _UpdateCheckScreenState();
}

class _UpdateCheckScreenState extends State<UpdateCheckScreen> {
  bool _isLoading = true;
  bool _updateRequired = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      print("Checking for updates...");
      
      final response = await supabase
        .from('app_control')
        .select()
        .eq('key', 'isupdated')
        .single();
        
      if (response != null) {
        final value = response['value'];
        print("Supabase app_control/isupdated value: $value");
        
        setState(() {
          _updateRequired = value == "no";
          _isLoading = false;
          _errorMessage = '';
        });
        
        if (!_updateRequired && mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
            );
          });
        }
      } else {
        // إذا لم يتم العثور على البيانات، نحاول التحقق من loginis
        final loginResponse = await supabase
          .from('app_control')
          .select()
          .eq('key', 'loginis')
          .single();
          
        if (loginResponse != null) {
          final loginValue = loginResponse['value'];
          print("Supabase app_control/loginis value: $loginValue");
          
          setState(() {
            _updateRequired = false;
            _isLoading = false;
            _errorMessage = '';
          });
          
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
              );
            });
          }
        } else {
          print("Supabase path app_control/loginis does not exist");
          setState(() {
            _updateRequired = false;
            _isLoading = false;
            _errorMessage = '';
          });
          
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
              );
            });
          }
        }
      }
    } catch (e) {
      print("Error checking for updates: $e");
      setState(() {
        _updateRequired = false;
        _isLoading = false;
        _errorMessage = 'حدث خطأ أثناء التحقق من التحديثات';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'images/logo.png',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'جاري التحقق من التحديثات...',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    } else if (_updateRequired) {
      // هذا هو الجزء الذي يظهر رسالة التحديث الإجباري
      return WillPopScope(
        onWillPop: () async => false, // منع الرجوع للخلف
        child: Scaffold(
          backgroundColor: backgroundColor,
          body: Center(
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'تحديث إجباري مطلوب',
                    style: GoogleFonts.cairo(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'يجب تحديث التطبيق للاستمرار في استخدامه. تم إصدار تحديثات ضرورية لتحسين الأداء والأمان.',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: Colors.grey[300],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final Uri url = Uri.parse('https://discord.gg/PeMT6jZnBn');
                      try {
                        await launchUrl(url);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('لا يمكن فتح الرابط: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.discord),
                    label: Text(
                      'انضم للديسكورد للتحديث',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7289DA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ملاحظة: لن تتمكن من استخدام التطبيق حتى يتم التحديث',
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'images/logo.png',
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'جاري تحميل التطبيق...',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool _isLoading = true;
  bool _requireLogin = true;

  @override
  void initState() {
    super.initState();
    _checkLoginRequirement();
  }

  Future<void> _checkLoginRequirement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastLoginTime = prefs.getInt('lastLoginTime') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      
      final sessionValid = isLoggedIn && (currentTime - lastLoginTime < 345600000);
      
      if (sessionValid) {
        setState(() {
          _requireLogin = false;
          _isLoading = false;
        });
        return;
      }
      
      final response = await supabase
        .from('app_control')
        .select()
        .eq('key', 'loginis')
        .single();
        
      if (response != null) {
        final value = response['value'];
        setState(() {
          _requireLogin = value == "yes";
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error checking login requirement: $e");
      setState(() {
        _requireLogin = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'images/logo.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'جاري تحميل التطبيق...',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      if (_requireLogin) {
        return const LoginScreen();
      } else {
        return const MainScreen();
      }
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setInt('lastLoginTime', DateTime.now().millisecondsSinceEpoch);
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          if (e is AuthException) {
            _errorMessage = e.message;
          } else {
            _errorMessage = 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'images/logo.png',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 32),
              Text(
                'تسجيل الدخول إلى XCORD',
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.email, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال البريد الإلكتروني';
                        }
                        if (!value.contains('@')) {
                          return 'يرجى إدخال بريد إلكتروني صحيح';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        labelStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.lock, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى إدخال كلمة المرور';
                        }
                        if (value.length < 6) {
                          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        }
                        return null;
                      },
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              )
                            : Text(
                                'تسجيل الدخول',
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        final Uri url = Uri.parse('https://discord.gg/PeMT6jZnBn');
                        try {
                          await launchUrl(url);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('لا يمكن فتح الرابط: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'نسيت كلمة المرور؟ تواصل معنا على ديسكورد',
                        style: GoogleFonts.cairo(
                          color: primaryColor,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _showLogoutButton = false;

  final List<NavigationItem> _items = [
    NavigationItem(
      title: 'الرئيسية',
      icon: Icons.home_rounded,
    ),
    NavigationItem(
      title: 'أدوات XCAGO',
      icon: Icons.build_rounded,
      tools: [
        Tool(
          name: 'نسخ سيرفرات',
          imagePath: 'images/copyer.png',
          description: 'نسخ سيرفر ديسكورد بالكامل',
          color: Color(0xFF9C27B0),
        ),
        Tool(
          name: 'تهكير سيرفرات',
          imagePath: 'images/nuke.png',
          description: 'اداه تهكير سيرفرات v1.0',
          color: Color(0xFFE91E63),
        ),
        Tool(
          name: 'سبام شات',
          imagePath: 'images/spam.png',
          description: 'سبام شات v1.0',
          color: Color(0xFF2196F3),
        ),
        Tool(
          name: 'فحص يوزرات',
          imagePath: 'images/checker.png',
          description: 'فحص يوزرات على منصات متعددة',
          color: Color(0xFFFF9800),
        ),
        Tool(
          name: 'أداة بوستات',
          imagePath: 'images/boost-tool.png',
          description: 'أداة بوستات (قيد التطوير)',
          color: Color(0xFF4CAF50),
        ),
      ],
    ),
    NavigationItem(
      title: 'التحديثات والأدوات',
      icon: Icons.update_rounded,
    ),
    NavigationItem(
      title: 'اكس بوت',
      icon: Icons.smart_toy_rounded,
    ),
    NavigationItem(
      title: 'الغرف',
      icon: Icons.meeting_room_rounded,
    ),
    NavigationItem(
      title: 'الإعدادات',
      icon: Icons.settings_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkLoginSystem();
  }

  Future<void> _checkLoginSystem() async {
    try {
      final response = await supabase
        .from('app_control')
        .select()
        .eq('key', 'loginis')
        .single();
      
      if (response != null) {
        final value = response['value'];
        print("Supabase app_control/loginis value: $value");
        
        setState(() {
          _showLogoutButton = value == "yes";
        });
      }
    } catch (e) {
      print("Error checking login system: $e");
      setState(() {
        _showLogoutButton = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        toolbarHeight: 70,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: Colors.white,
            size: 28,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _items[_selectedIndex].title,
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'إصدارك الحالي للتطبيق لا يدعم الإشعارات. يرجى الانضمام لمجتمعنا على ديسكورد لمتابعة آخر الإصدارات.',
                        style: GoogleFonts.cairo(),
                      ),
                      backgroundColor: primaryColor,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'انضمام',
                        textColor: Colors.white,
                        onPressed: () async {
                          final Uri url = Uri.parse('https://discord.gg/PeMT6jZnBn');
                          try {
                            await launchUrl(url);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('لا يمكن فتح الرابط: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      drawer: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: MediaQuery.of(context).size.width * 0.75,
        child: Drawer(
          backgroundColor: surfaceColor,
          child: Column(
            children: [
              Container(
                height: 150,
                color: appBarColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          'XC',
                          style: GoogleFonts.cairo(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'XCORD',
                        style: GoogleFonts.cairo(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isSelected = _selectedIndex == index;
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.icon,
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () {
                          if (index == 0 || index == 1) {
                            setState(() {
                              _selectedIndex = index;
                            });
                            Navigator.pop(context);
                          } else {
                            Navigator.pop(context);
                            _showFeatureNotAvailableDialog();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.grey),
              if (_showLogoutButton)
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.white),
                  title: Text(
                    'تسجيل الخروج',
                    style: GoogleFonts.cairo(color: Colors.white),
                  ),
                  onTap: () async {
                    await supabase.auth.signOut();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('isLoggedIn', false);
                    if (mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (context) => const AuthCheckScreen()),
                      );
                    }
                  },
                ),
            ],
          ),
        ),
      ),
      body: _selectedIndex == 0
          ? _buildHomeScreen()
          : _selectedIndex == 1
              ? _buildToolsScreen()
              : const Center(
                  child: Text(
                    'قريباً...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
    );
  }

  Widget _buildHomeScreen() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'images/logo.png',
                    width: 350,
                    height: 350,
                  ),
                ),
                const SizedBox(height: 29),
                
                Container(
                  height: 180,
                  child: PageView.builder(
                    controller: PageController(viewportFraction: 0.85),
                    itemCount: _items[1].tools!.length,
                    itemBuilder: (context, index) {
                      final tool = _items[1].tools![index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tool.color.withOpacity(0.7),
                              tool.color.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: tool.color.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (tool.name == 'تهكير سيرفرات') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const NukeScreen(),
                                  ),
                                );
                              } else if (tool.name == 'سبام شات') {
                                _showTokenTypeDialog(context);
                              } else if (tool.name == 'نسخ سيرفرات') {
                                _showCopyServerDialog(context);
                              } else if (tool.name == 'أداة بوستات') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('هذه الأداة قيد التطوير حالياً'),
                                    backgroundColor: primaryColor,
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.asset(
                                            tool.imagePath,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tool.name,
                                              style: GoogleFonts.cairo(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              tool.description,
                                              style: GoogleFonts.cairo(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              'استخدام',
                                              style: GoogleFonts.cairo(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.arrow_forward,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                const SizedBox(height: 40),
                
                Text(
                  'XCORD BETA VERSION 1.0',
                  style: GoogleFonts.righteous(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final Uri url = Uri.parse('https://discord.gg/PeMT6jZnBn');
                      try {
                        await launchUrl(url);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('لا يمكن فتح الرابط: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.discord,
                      size: 24,
                    ),
                    label: Text(
                      'انضم إلى سيرفر الديسكورد',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7289DA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolsScreen() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: _items[1].tools!.length,
      itemBuilder: (context, index) {
        final tool = _items[1].tools![index];
        return InkWell(
          onTap: () {
            if (tool.name == 'تهكير سيرفرات') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NukeScreen(),
                ),
              );
            } else if (tool.name == 'سبام شات') {
              _showTokenTypeDialog(context);
            } else if (tool.name == 'نسخ سيرفرات') {
              _showCopyServerDialog(context);
            } else if (tool.name == 'فحص يوزرات') {
              _showPlatformSelectionDialog(context);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: tool.color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        tool.imagePath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tool.color.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tool.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTokenTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'اختر نوع التوكن',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'يرجى اختيار نوع التوكن الذي تريد استخدامه',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserTokenScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7289DA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'توكن شخصي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NukeScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7289DA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'توكن بوت',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCopyServerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'نسخ سيرفر',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر نوع التوكن المستخدم للنسخ \n (قيد التطوير) قد يكون هناك بعض المشاكل ',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserCopyServerScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7289DA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'توكن شخصي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('النسخ عبر البوت تحت التطوير حالياً'),
                          backgroundColor: Color(0xFF7289DA),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7289DA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'توكن بوت',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPlatformSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'اختر المنصة',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'يرجى اختيار المنصة التي تريد فحص اليوزرات عليها',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildPlatformButton(
              context,
              'ديسكورد',
              const Color(0xFF7289DA),
              Icons.discord,
            ),
            const SizedBox(height: 10),
            _buildPlatformButton(
              context,
              'انستجرام',
              const Color(0xFFE1306C),
              Icons.camera_alt,
            ),
            const SizedBox(height: 10),
            _buildPlatformButton(
              context,
              'تيكتوك',
              const Color(0xFF000000),
              Icons.music_note,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformButton(
    BuildContext context,
    String platform,
    Color color,
    IconData icon,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UsernameCheckerScreen(
                platform: platform,
                platformColor: color,
              ),
            ),
          );
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(
          platform,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _showFeatureNotAvailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'هذا القسم غير متاح',
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'هذا القسم غير متاح في إصدارك الحالي',
              style: GoogleFonts.cairo(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'يرجى الانضمام إلى مجتمعنا على ديسكورد للحصول على آخر التحديثات',
              style: GoogleFonts.cairo(
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إغلاق',
              style: GoogleFonts.cairo(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final Uri url = Uri.parse('https://discord.gg/PeMT6jZnBn');
              try {
                await launchUrl(url);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('لا يمكن فتح الرابط: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.discord),
            label: Text(
              'انضم الآن',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7289DA),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(Tool tool) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tool.color.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  tool.imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: tool.color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tool.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  tool.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final List<Tool>? tools;

  NavigationItem({
    required this.title,
    required this.icon,
    this.tools,
  });
}

class Tool {
  final String name;
  final String description;
  final String imagePath;
  final Color color;

  Tool({
    required this.name,
    required this.description,
    required this.imagePath,
    required this.color,
  });
}
