import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.26:8000';

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

  // ── Upload Voice Profile (3 recordings) ───────────────
  Future<Map<String, dynamic>> uploadVoiceProfile3({
    required String audioPath1,
    required String audioPath2,
    required String audioPath3,
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
      });

      final response = await _dio.post(
        '/voice-profile',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== VOICE UPLOAD 3 ERROR ===');
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
        'message':
        e.response?.data?['detail'] ?? 'Failed to get challenge'
      };
    }
  }

  // ── Verify Voice (forgot password) ────────────────────
  Future<Map<String, dynamic>> verifyVoice({
    required String audioPath,
    required String passphrase,
  }) async {
    try {
      print('=== VERIFY VOICE ===');

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

      print('=== VERIFY VOICE RESPONSE ===');
      print(response.data);

      // Print fake probability for Mahmoud's calibration
      if (response.data['fake_probability'] != null) {
        print('Fake probability: ${response.data['fake_probability']}');
      }

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== VOICE VERIFY ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message':
        e.response?.data?['detail'] ?? 'Voice verification failed'
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

      print('=== VOICE LOGIN RESPONSE ===');
      print(response.data);

      // Print fake probability for Mahmoud's calibration
      if (response.data['fake_probability'] != null) {
        print('Fake probability: ${response.data['fake_probability']}');
      }

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
        'message':
        e.response?.data?['detail'] ?? 'Voice not recognized'
      };
    }
  }
  // ── Forgot Password — Get Phrase ───────────────────────
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      print('=== FORGOT PASSWORD REQUEST ===');
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.post(
        '/forgot-password',
        data: {'email': email},
        options: Options(contentType: 'application/json'),
      );

      print('=== FORGOT PASSWORD SUCCESS ===');
      print(response.data);

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== FORGOT PASSWORD ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ??
            'Something went wrong. Please try again.'
      };
    }
  }

// ── Reset Password — Verify Voice ─────────────────────
  Future<Map<String, dynamic>> resetPasswordVerifyVoice({
    required String email,
    required String phrase,
    required String audioPath,
  }) async {
    try {
      print('=== RESET PASSWORD VERIFY VOICE ===');

      final formData = FormData.fromMap({
        'email': email,
        'phrase': phrase,
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'voice_reset.wav',
        ),
      });

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.post(
        '/reset-password/verify-voice',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      print('=== RESET VERIFY SUCCESS ===');
      print(response.data);

      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== RESET VERIFY ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': 'Voice verification failed'
      };
    }
  }

// ── Reset Password — Confirm New Password ─────────────
  Future<Map<String, dynamic>> resetPasswordConfirm({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      print('=== RESET PASSWORD CONFIRM ===');

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.post(
        '/reset-password/confirm',
        data: {
          'reset_token': resetToken,
          'new_password': newPassword,
        },
        options: Options(contentType: 'application/json'),
      );

      print('=== RESET PASSWORD SUCCESS ===');
      return {'success': true, 'data': response.data};
    } on DioException catch (e) {
      print('=== RESET PASSWORD ERROR ===');
      print('Status: ${e.response?.statusCode}');
      print('Data: ${e.response?.data}');
      return {
        'success': false,
        'message': e.response?.data?['detail'] ??
            'Password reset failed. Please try again.'
      };
    }
  }
}