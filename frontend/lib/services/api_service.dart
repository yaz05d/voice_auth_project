import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.141:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
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

  // ── Register ───────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      print('=== REGISTER REQUEST ===');
      final response = await _dio.post('/register', data: {
        'full_name': fullName,
        'email': email,
        'password': password,
      });
      print('=== REGISTER SUCCESS ===');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== REGISTER ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Registration failed'
      };
    }
  }

  // ── Login ──────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {
          'username': email,
          'password': password,
          'grant_type': 'password',
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );
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

  // ── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // ── Is Logged In ───────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  // ── Get Profile ────────────────────────────────────────
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

  // ── Upload Voice Profile (5 recordings) ───────────────
  Future<Map<String, dynamic>> uploadVoiceProfile5({
    required String audioPath1,
    required String audioPath2,
    required String audioPath3,
    required String audioPath4,
    required String audioPath5,
    String passphrase = 'my voice is my password',
  }) async {
    try {
      final formData = FormData.fromMap({
        'passphrase': passphrase,
        'audio1': await MultipartFile.fromFile(
          audioPath1,
          filename: 'voice1.wav',
        ),
        'audio2': await MultipartFile.fromFile(
          audioPath2,
          filename: 'voice2.wav',
        ),
        'audio3': await MultipartFile.fromFile(
          audioPath3,
          filename: 'voice3.wav',
        ),
        'audio4': await MultipartFile.fromFile(
          audioPath4,
          filename: 'voice4.wav',
        ),
        'audio5': await MultipartFile.fromFile(
          audioPath5,
          filename: 'voice5.wav',
        ),
      });

      final response = await _dio.post(
        '/voice-profile',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== VOICE UPLOAD 5 ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Voice upload failed'
      };
    }
  }

  // ── Get Voice Challenge ────────────────────────────────
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

  // ── Verify Voice (forgot password) ────────────────────
  Future<Map<String, dynamic>> verifyVoice({
    required String audioPath,
    required String passphrase,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      print('=== VERIFY VOICE ===');
      print('Token: $token');

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'voice_verify.wav',
        ),
        'passphrase': passphrase,
      });

      final response = await _dio.post(
        '/verify-voice',
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

  // ── Voice Login (no token needed) ─────────────────────
  Future<Map<String, dynamic>> voiceLogin({
    required String audioPath,
    required String passphrase,
  }) async {
    try {
      print('=== VOICE LOGIN ===');
      print('Passphrase: $passphrase');

      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'voice_login.wav',
        ),
        'passphrase': passphrase,
      });

      // Fresh Dio — no token for voice login
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.post(
        '/voice/login',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.data['access_token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', response.data['access_token']);
      }

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== VOICE LOGIN ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ?? 'Voice not recognized'
      };
    }
  }
}