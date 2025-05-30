import 'dart:async';
import 'package:cosaapp/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignIn extends StatelessWidget {
  const SignIn({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    return Scaffold(
      // Add resizeToAvoidBottomInset to prevent keyboard overlap issues
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: isSmallScreen
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _Logo(),
                      _FormContent(),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(32.0),
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Row(
                      children: const [
                        Expanded(child: _Logo()),
                        Expanded(child: Center(child: _FormContent())),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    // Adjust logo size based on screen size
    final double logoSize = isSmallScreen ? 300 : 400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/cosaapp.png',
          width: logoSize,
          height: logoSize,
        ),
      ],
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent();

  @override
  State<_FormContent> createState() => __FormContentState();
}

class __FormContentState extends State<_FormContent> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  late Dio _dio;

  @override
  void initState() {
    super.initState();
    _initializeDio();
    _loadRememberedCredentials();
  }

  void _initializeDio() {
    // Gunakan ApiConfig untuk mendapatkan instance Dio yang terkonfigurasi
    _dio = ApiConfig.getDioClient();
  }

  // Future<void> _loadRememberedEmail() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     setState(() {
  //       _emailController.text = prefs.getString('remembered_email') ?? '';
  //       _rememberMe = prefs.getBool('remember_me') ?? false;
  //     });
  //   } catch (e) {
  //     _showError('Failed to load saved credentials');
  //   }
  // }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Menggunakan endpoint dari ApiConfig
      print(
          'Attempting to connect to ${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}');

      final response = await _dio.post(
        ApiConfig.loginEndpoint, // Gunakan endpoint dari ApiConfig
        data: {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );

      if (response.statusCode == 200) {
        await _handleSuccessfulLogin(response.data);
      } else {
        _showError(response.data['message'] ?? 'Login failed');
      }
    } on DioException catch (e) {
      // Penanganan error tetap sama
      print('DioException caught: ${e.type} - ${e.message}');
      String errorMessage;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          errorMessage =
              'Connection timed out. Server might be overloaded or network issues detected.';
          break;
        case DioExceptionType.sendTimeout:
          errorMessage =
              'Send timeout occurred. Check network connection quality.';
          break;
        case DioExceptionType.receiveTimeout:
          errorMessage =
              'Receive timeout occurred. Server response is taking too long.';
          break;
        case DioExceptionType.connectionError:
          errorMessage =
              'Connection error. Please verify server address and network connection.';
          break;
        case DioExceptionType.badResponse:
          errorMessage = e.response?.data['message'] ??
              'Server returned error: ${e.response?.statusCode}';
          break;
        default:
          errorMessage = 'Unexpected error: ${e.message}';
      }
      _showError(errorMessage);
    } catch (e) {
      print('Unexpected error: $e');
      _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadRememberedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _emailController.text = prefs.getString('remembered_email') ?? '';
        _passwordController.text = prefs.getString('remembered_password') ?? '';
        _rememberMe = prefs.getBool('remember_me') ?? false;
      });
    } catch (e) {
      _showError('Failed to load saved credentials');
    }
  }

  Future<void> _handleSuccessfulLogin(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = data['data']['token'];
      await prefs.setString('token', token);
      await prefs.setString('name', data['data']['name']);
      await prefs.setString('email', data['data']['email']);

      if (_rememberMe) {
        await prefs.setString('remembered_email', _emailController.text.trim());
        await prefs.setString(
            'remembered_password', _passwordController.text.trim());
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('remembered_email');
        await prefs.remove('remembered_password');
        await prefs.setBool('remember_me', false);
      }

      print("Saved name: ${data['data']['name']}"); // Debugging
      // Opsional: Inisialisasi dio dengan token untuk digunakan setelah navigasi
      // _dio = ApiConfig.getDioClient(token: token);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/dashboard');
    } catch (e) {
      _showError('Failed to save login information');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Widget build tetap sama seperti sebelumnya
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  "Login Here",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color.fromARGB(255, 179, 4, 4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 179, 4, 4), width: 2),
                  ),
                ),
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color.fromARGB(255, 179, 4, 4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color.fromARGB(255, 179, 4, 4), width: 2),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) => (value == null || value.length < 6)
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      activeColor: const Color.fromARGB(255, 179, 4, 4),
                      onChanged: (bool? value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _rememberMe = !_rememberMe;
                      });
                    },
                    child: const Text('Remember me'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 179, 4, 4),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.3),
                  ).copyWith(
                    overlayColor: MaterialStateProperty.resolveWith<Color?>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.pressed)) {
                          return Colors.white.withOpacity(0.2);
                        }
                        if (states.contains(MaterialState.hovered)) {
                          return Colors.white.withOpacity(0.1);
                        }
                        return null;
                      },
                    ),
                    elevation: MaterialStateProperty.resolveWith<double>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.pressed)) {
                          return 1;
                        }
                        if (states.contains(MaterialState.hovered)) {
                          return 4;
                        }
                        return 2;
                      },
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: _isLoading
                            ? const Icon(
                                Icons.refresh,
                                key: ValueKey('loadingIcon'),
                                color: Colors.white,
                                size: 24.0,
                              )
                            : const Icon(
                                Icons.login,
                                key: ValueKey('loginIcon'),
                                color: Colors.white,
                                size: 24.0,
                              ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                        child: Text(
                          _isLoading ? 'Loading...' : 'Sign In',
                          key: ValueKey(
                              _isLoading ? 'loadingText' : 'signInText'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Add bottom padding to ensure content is visible above keyboard
              SizedBox(
                  height:
                      MediaQuery.of(context).viewInsets.bottom > 0 ? 16 : 0),
            ],
          ),
        ),
      ),
    );
  }
}
