import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'src/idtra_camera_view.dart';
import 'src/models/verification_result.dart';

/// Idtra Biometrics Main Controller
class IdtraBiometrics {
  static const String _defaultBaseUrl = 'https://idtra.com';

  /// Start the live camera face verification workflow.
  /// 
  /// Displays a customized oval camera overlay with interactive liveness challenges.
  /// Captures verified selfie and compares against official NIMC / BVN record.
  static Future<IdtraVerificationResult?> startVerification({
    required BuildContext context,
    required String apiKey,
    String? nin,
    String? bvn,
    String? customBaseUrl,
  }) async {
    assert(nin != null || bvn != null, 'Either NIN or BVN must be provided');

    final String serviceType = bvn != null ? 'BVN' : 'NIN';
    final String targetNumber = (bvn ?? nin)!;
    final String baseUrl = customBaseUrl ?? _defaultBaseUrl;

    return await Navigator.of(context).push<IdtraVerificationResult>(
      MaterialPageRoute(
        builder: (context) => IdtraCameraView(
          apiKey: apiKey,
          serviceType: serviceType,
          targetNumber: targetNumber,
          baseUrl: baseUrl,
        ),
      ),
    );
  }

  /// Direct API Call: Compare base64 image against official record without UI
  static Future<IdtraVerificationResult> directVerify({
    required String apiKey,
    required String serviceType,
    required String number,
    required String base64Image,
    String? customBaseUrl,
  }) async {
    final baseUrl = customBaseUrl ?? _defaultBaseUrl;
    final endpoint = serviceType.toUpperCase() == 'BVN'
        ? '$baseUrl/api/biometrics/bvn-verify'
        : '$baseUrl/api/biometrics/nin-verify';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        serviceType.toLowerCase(): number,
        'image': base64Image,
      }),
    );

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return IdtraVerificationResult.fromJson(body);
    } else {
      throw IdtraException(body['message'] ?? 'Verification failed with status ${response.statusCode}');
    }
  }
}

class IdtraException implements Exception {
  final String message;
  IdtraException(this.message);

  @override
  String toString() => 'IdtraException: $message';
}
