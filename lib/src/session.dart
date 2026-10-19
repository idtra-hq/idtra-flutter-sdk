import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Outcome of a hosted verification session (state only: no personal data on the device).
/// Fetch the full result on your server: GET /api/biometrics/session/{id}/result with your API key, or use the webhook.
class IdtraSessionResult {
  IdtraSessionResult({
    required this.sessionId,
    required this.status,
    this.isMatch,
    this.confidence,
    this.message,
    this.attemptsLeft,
    required this.rawJson,
  });

  final String sessionId;

  /// completed, failed, expired, or cancelled (the user left before finishing).
  final String status;
  final bool? isMatch;
  final double? confidence;
  final String? message;
  final int? attemptsLeft;
  final Map<String, dynamic> rawJson;

  bool get isVerified => status == 'completed' && isMatch == true;

  factory IdtraSessionResult.fromJson(String sessionId, Map<String, dynamic> j) => IdtraSessionResult(
        sessionId: sessionId,
        status: '${j['status'] ?? 'unknown'}',
        isMatch: j['is_match'] as bool?,
        confidence: (j['confidence'] as num?)?.toDouble(),
        message: (j['match_message'] ?? j['error_message']) as String?,
        attemptsLeft: (j['attempts_left'] as num?)?.toInt(),
        rawJson: j,
      );
}

/// Opens the hosted verification page (in-app browser: Chrome Custom Tabs / SFSafariViewController, where the
/// camera works natively) and waits for the session to finish.
class IdtraSessionRunner with WidgetsBindingObserver {
  IdtraSessionRunner(this.verificationUrl, {this.pollEvery = const Duration(seconds: 2), this.timeout = const Duration(minutes: 15)});

  final String verificationUrl;
  final Duration pollEvery;
  final Duration timeout;

  static const _final = {'completed', 'failed', 'expired'};

  Future<IdtraSessionResult> run() async {
    final uri = Uri.parse(verificationUrl);
    final m = RegExp(r'/verify/s/([A-Za-z0-9_]+)').firstMatch(uri.path);
    if (m == null) throw ArgumentError('verificationUrl is not an Idtra verification link');
    final sessionId = m.group(1)!;
    final statusUri = uri.replace(path: '/api/biometrics/session/$sessionId/status', query: '');

    final done = Completer<IdtraSessionResult>();
    var last = <String, dynamic>{'status': 'in_progress'};
    Timer? timer;
    var resumedChecks = 0;

    Future<void> check() async {
      try {
        final res = await http.get(statusUri, headers: {'Accept': 'application/json'});
        last = jsonDecode(res.body) as Map<String, dynamic>;
        if (_final.contains(last['status']) && !done.isCompleted) {
          done.complete(IdtraSessionResult.fromJson(sessionId, last));
        }
      } catch (_) {/* keep polling */}
    }

    void onResumed() {
      // The user came back to the app (closed the browser). Give the server a few more checks, then report.
      resumedChecks = 1;
    }

    _onResumed = onResumed;
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(pollEvery, (_) async {
      await check();
      if (resumedChecks > 0 && !done.isCompleted) {
        resumedChecks += 1;
        if (resumedChecks > 3) {
          done.complete(IdtraSessionResult.fromJson(sessionId, {...last, 'status': 'cancelled'}));
        }
      }
    });

    if (!await launchUrl(uri, mode: LaunchMode.inAppBrowserView)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    final result = await done.future.timeout(timeout,
        onTimeout: () => IdtraSessionResult.fromJson(sessionId, {...last, 'status': 'expired'}));
    timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    try {
      await closeInAppWebView();
    } catch (_) {}
    return result;
  }

  void Function()? _onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResumed?.call();
  }
}
