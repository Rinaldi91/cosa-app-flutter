import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cosaapp/screens/auth/sign_in.dart';
import 'package:cosaapp/screens/dashboard/dashboard_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cosaapp/screens/result/result_page.dart';

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
      home: const ConnectivityWrapper(
        child: SplashScreen(),
      ),
      routes: {
        '/signin': (context) => const ConnectivityWrapper(child: SignIn()),
        '/dashboard': (context) =>
            const ConnectivityWrapper(child: DashboardPage()),
        '/result': (context) => const ConnectivityWrapper(child: ResultPage()),
      },
    );
  }
}

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
    // Cek koneksi awal
    final initialResult = await Connectivity().checkConnectivity();
    if (initialResult == ConnectivityResult.none) {
      if (mounted) {
        _showNoInternetDialog();
      }
    }

    // Mulai monitoring koneksi
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        if (mounted && !_isDialogShowing) {
          _showNoInternetDialog();
        }
      } else if (_isDialogShowing) {
        Navigator.of(context).pop();
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

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/signin');
        // Navigator.pushReplacementNamed(context, '/dashboard');
      }
    });
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
                'assets/images/cosaapp.png',
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
