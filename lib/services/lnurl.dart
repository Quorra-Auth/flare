import '../models/lnurl_auth_request.dart';
import '../utils/lnurl_input.dart';

class LnurlService {
  LnurlAuthRequest parseLnurlAuth(Uri uri) {
    final callback = uri;
    final tag = callback.queryParameters['tag'];
    final k1 = callback.queryParameters['k1'];
    final action = callback.queryParameters['action'] ?? 'login';

    if (tag != 'login') {
      throw const UnsupportedLinkException(unsupportedLnurlMessage);
    }

    if (k1 == null || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(k1)) {
      throw Exception('Invalid or missing k1');
    }

    if (callback.host.isEmpty) {
      throw Exception('Missing callback host');
    }

    return LnurlAuthRequest(
      callback: callback,
      k1: k1.toLowerCase(),
      action: action,
      domain: callback.host.toLowerCase(),
    );
  }
}
