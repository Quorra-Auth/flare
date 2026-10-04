final _lnurlPattern = RegExp(r'^lnurl1[02-9ac-hj-np-z]+$');

/// Extracts a bech32 LNURL from text found in a QR code or link.
///
/// Accepts `lightning:LNURL1...`, a bare `LNURL1...` (QR codes are often
/// uppercase), or a web URL carrying it in a `lightning` query parameter.
/// Returns it lowercased, or null if no LNURL is found.
String? extractLnurl(String raw) {
  var text = raw.trim();

  if (text.toLowerCase().startsWith('lightning:')) {
    text = text.substring('lightning:'.length);
    while (text.startsWith('/')) {
      text = text.substring(1);
    }
  } else if (RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) {
    final param = Uri.tryParse(text)?.queryParameters['lightning'];
    if (param == null) return null;
    return extractLnurl(param);
  }

  final candidate = text.toLowerCase();
  return _lnurlPattern.hasMatch(candidate) ? candidate : null;
}
