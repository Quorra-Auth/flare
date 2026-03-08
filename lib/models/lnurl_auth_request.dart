class LnurlAuthRequest {
  final Uri callback;
  final String k1;
  final String action;
  final String domain;

  LnurlAuthRequest({
    required this.callback,
    required this.k1,
    required this.action,
    required this.domain,
  });
}