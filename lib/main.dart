import 'dart:async';
import 'package:cosaapp/config/api_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cosaapp/screens/auth/sign_in.dart';
import 'package:cosaapp/screens/dashboard/dashboard_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cosaapp/screens/result/result_page.dart';
// 1. Tambahkan import untuk SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 255, 255, 255)),
        useMaterial3: true,
      ),
      // SplashScreen tetap menjadi halaman utama
      home: const ConnectivityWrapper(
        child: SplashScreen(),
      ),
      // Rute Anda tetap sama
      routes: {
        '/signin': (context) => const ConnectivityWrapper(child: SignIn()),
        '/dashboard': (context) =>
            const ConnectivityWrapper(child: DashboardPage()),
        '/result': (context) => const ConnectivityWrapper(child: ResultPage()),
      },
    );
  }
}

// Tidak ada perubahan pada ConnectivityWrapper
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  _ConnectivityWrapperState createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isDialogShowing = false;
  StreamSubscription<ConnectivityResult>? _subscription;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final initialResult = await Connectivity().checkConnectivity();
    if (initialResult == ConnectivityResult.none) {
      if (mounted) {
        _showNoInternetDialog();
      }
    }

    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        if (mounted && !_isDialogShowing) {
          _showNoInternetDialog();
        }
      } else if (_isDialogShowing) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        _isDialogShowing = false;
      }
    });
  }

  void _showNoInternetDialog() {
    if (!_isDialogShowing && mounted) {
      _isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              contentPadding: const EdgeInsets.all(16),
              title: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: const [
                  Icon(Icons.signal_wifi_off, color: Colors.red),
                  Text(
                    'No Internet Connection',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
              content: const Text(
                'Please check your internet connection and try again.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  child: const Text('Try Again'),
                  onPressed: () async {
                    final result = await Connectivity().checkConnectivity();
                    if (result != ConnectivityResult.none) {
                      if (mounted) {
                        Navigator.of(context).pop();
                        _isDialogShowing = false;
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ).then((_) => _isDialogShowing = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });

    _checkLoginStatus();
  }

  // Fungsi baru untuk memverifikasi token ke API
  Future<bool> _verifyToken() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    // --- TAMBAHKAN PRINT UNTUK DEBUGGING ---
    print("--- Verifying Token ---");
    print("Retrieved Token from Storage: $token");

    if (token == null || token.isEmpty) {
      print("Verification failed: No token found.");
      return false;
    }

    try {
      final dio = ApiConfig.getDioClient(token: token);
      final response = await dio.get(ApiConfig.validateTokenEndpoint);

      // --- TAMBAHKAN PRINT UNTUK DEBUGGING ---
      print("Verification Response Status Code: ${response.statusCode}");
      print("Verification Response Body: ${response.data}");

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        //
        print("Verification successful: Token is valid.");
        return true;
      } else {
        print("Verification failed: Server responded that token is invalid.");
        return false;
      }
    } on DioException catch (e) {
      // --- TAMBAHKAN PRINT UNTUK DEBUGGING ---
      print("Verification failed with DioException: ${e.message}");
      if (e.response != null) {
        print("Error Response Body: ${e.response?.data}");
      }
      return false;
    } catch (e) {
      print("An unexpected error occurred during token verification: $e");
      return false;
    }
  }

  Future<void> _checkLoginStatus() async {
    // Beri jeda agar splash screen terlihat
    await Future.delayed(const Duration(seconds: 3));

    // Panggil fungsi verifikasi token
    bool isTokenValid = await _verifyToken();

    // Pastikan widget masih ada di tree sebelum navigasi
    if (mounted) {
      if (isTokenValid) {
        // Jika token valid, arahkan ke dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        // Jika token tidak valid, hapus sisa data lama dan arahkan ke sign in
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('name');
        await prefs.remove('email');

        Navigator.pushReplacementNamed(context, '/signin');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(250, 255, 255, 255),
      body: Center(
        child: AnimatedOpacity(
          duration: const Duration(seconds: 2),
          opacity: _opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/splash.png',
                width: 300,
                height: 300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
