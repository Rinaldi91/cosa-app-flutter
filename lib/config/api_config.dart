import 'package:dio/dio.dart';

class ApiConfig {
  // Gunakan base URL production
  static const String devBaseUrl = 'http://103.150.91.89:5000';
  static const String prodBaseUrl = 'https://api.fanscosa.co.id';

  // Baca flavor dari environment variable
  static const String flavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static String get baseUrl => flavor == 'prod' ? prodBaseUrl : devBaseUrl;

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

  static Future<Response> postData({
    required String endpoint,
    required Map<String, dynamic> data,
    String? token,
    Map<String, dynamic>? queryParameters,
  }) async {
    final dio = getDioClient(token: token);

    print('Posting to: ${getUrl(endpoint)}');
    print('Data: $data');

    try {
      final response = await dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      print('Response: ${response.data}');
      return response;
    } on DioException catch (e) {
      print('Error posting data: ${e.message}');
      rethrow;
    }
  }

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
      print('Error updating data: ${e.message}');
      rethrow;
    }
  }

  static const String loginEndpoint = '/auth/login';
  static const String validateTokenEndpoint = '/auth/verify-token'; 
  static const String registerEndpoint = '/auth/register';
  static const String dashboardEndpoint = '/dashboard';
  static const String testGlucosaEndpoint = '/api/test-glucosa';
  static const String patientEndpoint = '/api/patients';
  static const String testGlucosaPatientEndpoint ='/api/test-glucosa/patient/{patientId}/glucose-tests';
  static const String updateIsValidation = '/api/test-glucosa/{id}/validation';
  static const String connectionStatus = '/api/connection-status';
  static const String updateDataEndpoint = '/api/update-data';

  static String getUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      endpoint = endpoint.substring(1);
    }
    return '$baseUrl/$endpoint';
  }

  static String replacePathParameters(
      String endpoint, Map<String, dynamic> parameters) {
    String result = endpoint;
    parameters.forEach((key, value) {
      result = result.replaceAll('{$key}', value.toString());
    });
    return result;
  }
}
