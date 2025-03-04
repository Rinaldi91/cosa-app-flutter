// lib/config/api_config.dart

import 'package:dio/dio.dart';

class ApiConfig {
  // URL API dasar untuk mode pengembangan (development)
  static const String devBaseUrl = 'http://192.168.18.29:5000';

  // URL API dasar untuk mode produksi
  // Ganti dengan URL produksi Anda saat aplikasi siap dirilis
  static const String prodBaseUrl = 'https://api.cosaapp.com';

  // Flag untuk menentukan mode aplikasi (development atau production)
  static const bool isProduction = false;

  // Getter untuk mendapatkan baseUrl sesuai dengan mode aplikasi
  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;

  // Mendapatkan instance Dio yang sudah dikonfigurasi
  static Dio getDioClient({String? token}) {
    Dio dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    ));

    // Add interceptor for logging
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    return dio;
  }

  // Endpoint API
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String dashboardEndpoint = '/dashboard';
  static const String testGlucosaEndpoint = '/api/test-glucosa';
  static const String patientEndpoint = '/api/patients';
  static const String testGlucosaPatientEndpoint =
      '/api/test-glucosa/patient/{patientId}/glucose-tests';

  // Fungsi untuk membuat URL lengkap dengan endpoint
  static String getUrl(String endpoint) {
    // Pastikan endpoint tidak memiliki ganda slash
    if (endpoint.startsWith('/')) {
      endpoint = endpoint.substring(1);
    }
    return '$baseUrl/$endpoint';
  }
}
