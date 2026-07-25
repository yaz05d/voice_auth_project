import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class ApiService {
  // Change this to Mahmoud's IP when testing on real device
  static const String baseUrl = 'http://10.12.150.90:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Attach token to every request automatically
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  // ── Auth ──────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      print('=== REGISTER REQUEST ===');
      print('URL: $baseUrl/register');
      print('Data: full_name=$fullName, email=$email');

      final response = await _dio.post('/register', data: {
        'full_name': fullName,
        'email': email,
        'password': password,
      });

      print('=== REGISTER SUCCESS ===');
      print('Response: ${response.data}');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== REGISTER ERROR ===');
      print('Status code: ${e.response?.statusCode}');
      print('Error data: ${e.response?.data}');
      print('Error message: ${e.message}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Registration failed'
      };
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Mahmoud's login uses OAuth2 form format
      final response = await _dio.post(
        '/login',
        data: {
          'username': email, // OAuth2 uses 'username' not 'email'
          'password': password,
          'grant_type': 'password',
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      // Save token locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response.data['access_token']);

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== LOGIN ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Login failed'
      };
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await _dio.get('/profile');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to get profile'
      };
    }
  }
  Future<Map<String, dynamic>> uploadVoiceProfile({
    required String audioPath,
    String passphrase = 'my voice is my password',
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'voice_sample.wav',
        ),
        'passphrase': passphrase,
      });

      final response = await _dio.post(
        '/voice-profile',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== VOICE UPLOAD ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Voice upload failed'
      };
    }
  }

  Future<Map<String, dynamic>> getVoiceChallenge() async {
    try {
      final response = await _dio.get('/voice/challenge');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Failed to get challenge'
      };
    }
  }
  Future<Map<String, dynamic>> verifyVoice({
    required String audioPath,
    required String passphrase,
  }) async {
    try {
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'voice_verify.wav',
        ),
        'passphrase': passphrase,
      });

      final response = await _dio.post(
        '/voice/verify',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== VOICE VERIFY ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Voice verification failed'
      };
    }
  }

}