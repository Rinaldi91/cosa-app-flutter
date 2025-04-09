import 'package:dio/dio.dart';

class ApiConfig {
  // URLs remain the same
  static const String devBaseUrl = 'http://192.168.18.29:5000';
  static const String prodBaseUrl = 'https://api.cosaapp.com';
  static const bool isProduction = false;

  static String get baseUrl => isProduction ? prodBaseUrl : devBaseUrl;

  // Dio client setup remains the same
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

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    return dio;
  }

  // New function to handle POST requests
  static Future<Response> postData({
    required String endpoint,
    required Map<String, dynamic> data,
    String? token,
    Map<String, dynamic>? queryParameters,
  }) async {
    final dio = getDioClient(token: token);

    try {
      final response = await dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );

      return response;
    } on DioException catch (e) {
      // Log the error and rethrow
      print('Error posting data: ${e.message}');
      rethrow;
    }
  }

  // Function to handle data updates
  static Future<Response> updateData({
    required String endpoint,
    required Map<String, dynamic> data,
    String? token,
    Map<String, dynamic>? queryParameters,
  }) async {
    final dio = getDioClient(token: token);

    try {
      final response = await dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );

      return response;
    } on DioException catch (e) {
      // Log the error and rethrow
      print('Error updating data: ${e.message}');
      rethrow;
    }
  }

  // Existing endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String dashboardEndpoint = '/dashboard';
  static const String testGlucosaEndpoint = '/api/test-glucosa';
  static const String patientEndpoint = '/api/patients';
  static const String testGlucosaPatientEndpoint =
      '/api/test-glucosa/patient/{patientId}/glucose-tests';
  static const String updateIsValidation =
      '/api/test-glucosa/{patiendId}/validation';
  static const String connectionStatus = '/api/connection-status';

  // New endpoint for general data update
  static const String updateDataEndpoint = '/api/update-data';

  // Your existing URL formatter
  static String getUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      endpoint = endpoint.substring(1);
    }
    return '$baseUrl/$endpoint';
  }

  // Helper method for replacing path parameters
  static String replacePathParameters(
      String endpoint, Map<String, dynamic> parameters) {
    String result = endpoint;
    parameters.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }
}
