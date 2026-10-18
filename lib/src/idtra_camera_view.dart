import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'models/verification_result.dart';

class IdtraCameraView extends StatefulWidget {
  final String apiKey;
  final String serviceType;
  final String targetNumber;
  final String baseUrl;

  const IdtraCameraView({
    Key? key,
    required this.apiKey,
    required this.serviceType,
    required this.targetNumber,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<IdtraCameraView> createState() => _IdtraCameraViewState();
}

class _IdtraCameraViewState extends State<IdtraCameraView> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  String _stepPrompt = 'Center face inside oval';
  String _subPrompt = 'Hold device steady at eye level';
  double _progress = 0.25;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _isCameraReady = true;
      });

      _startLivenessSequence();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera initialization failed: $e')),
      );
    }
  }

  void _startLivenessSequence() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    setState(() {
      _stepPrompt = 'Blink your eyes';
      _subPrompt = 'Blink naturally while looking at camera';
      _progress = 0.65;
    });

    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    setState(() {
      _stepPrompt = 'Hold steady...';
      _subPrompt = 'Capturing biometric portrait';
      _progress = 0.90;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    _captureAndVerify();
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _stepPrompt = 'Verifying Biometrics';
      _subPrompt = 'Matching facial portrait against official database...';
      _progress = 1.0;
    });

    try {
      final imageFile = await _cameraController!.takePicture();
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,' + base64Encode(imageBytes);

      final endpoint = widget.serviceType == 'BVN'
          ? '${widget.baseUrl}/api/biometrics/bvn-verify'
          : '${widget.baseUrl}/api/biometrics/nin-verify';

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${widget.apiKey}',
        },
        body: jsonEncode({
          widget.serviceType.toLowerCase(): widget.targetNumber,
          'image': base64Image,
        }),
      );

      final Map<String, dynamic> body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = IdtraVerificationResult.fromJson(body);
        if (mounted) Navigator.of(context).pop(result);
      } else {
        _showError(body['message'] ?? 'Facial verification failed.');
      }
    } catch (e) {
      _showError('Verification error: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _stepPrompt = 'Verification Failed';
      _subPrompt = message;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Idtra Face KYC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: Container(
                width: 270,
                height: 350,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(160),
                  border: Border.all(color: const Color(0xFF3B82F6), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 30,
                    )
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _isCameraReady && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _stepPrompt,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _subPrompt,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: const Color(0xFF1E293B),
                color: const Color(0xFF3B82F6),
                minHeight: 6,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Spacer(),
            if (!_isProcessing)
              ElevatedButton.icon(
                onPressed: _captureAndVerify,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Capture Face Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
