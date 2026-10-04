final _lnurlPattern = RegExp(r'^lnurl1[02-9ac-hj-np-z]+$');
final _invoicePattern = RegExp(r'^ln(bc|tb|tbs|bcrt)[0-9a-z]+$');
final _bolt12Pattern = RegExp(r'^ln[oir]1[0-9a-z]+$');
final _lightningAddressPattern = RegExp(
  r'^[a-z0-9._+-]+@[a-z0-9-]+(\.[a-z0-9-]+)+$',
);

/// Thrown for valid Lightning links that Flare can't handle (anything that
/// isn't LNURL-auth). The message is meant to be shown to the user.
class UnsupportedLinkException implements Exception {
  final String message;

  const UnsupportedLinkException(this.message);

  @override
  String toString() => message;
}

const unsupportedLnurlMessage =
    "This LNURL isn't a login request. It may be for payments, withdrawals "
    'or channels. Flare only supports LNURL-auth.';

enum LightningInputKind { lnurl, invoice, offer, lightningAddress, unknown }

String _stripScheme(String raw) {
  var text = raw.trim();
  if (text.toLowerCase().startsWith('lightning:')) {
    text = text.substring('lightning:'.length);
    while (text.startsWith('/')) {
      text = text.substring(1);
    }
  }
  return text;
}

/// Extracts a bech32 LNURL from text found in a QR code or link.
///
/// Accepts `lightning:LNURL1...`, a bare `LNURL1...` (QR codes are often
/// uppercase), or a web URL carrying it in a `lightning` query parameter.
/// Returns it lowercased, or null if no LNURL is found.
String? extractLnurl(String raw) {
  final text = _stripScheme(raw);

  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) {
    final param = Uri.tryParse(text)?.queryParameters['lightning'];
    return param == null ? null : extractLnurl(param);
  }

  final candidate = text.toLowerCase();
  return _lnurlPattern.hasMatch(candidate) ? candidate : null;
}

/// Works out what kind of Lightning payload a link or QR code contains.
LightningInputKind classifyLightningInput(String raw) {
  if (extractLnurl(raw) != null) return LightningInputKind.lnurl;

  final text = _stripScheme(raw).toLowerCase();
  if (_invoicePattern.hasMatch(text)) return LightningInputKind.invoice;
  if (_bolt12Pattern.hasMatch(text)) return LightningInputKind.offer;
  if (_lightningAddressPattern.hasMatch(text)) {
    return LightningInputKind.lightningAddress;
  }
  return LightningInputKind.unknown;
}

/// User-facing explanation for a kind of input Flare doesn't support.
String unsupportedMessageFor(LightningInputKind kind) {
  return switch (kind) {
    LightningInputKind.invoice || LightningInputKind.offer =>
      'This is a Lightning payment request. Flare is a login keychain and '
          "can't pay. It only supports LNURL-auth.",
    LightningInputKind.lightningAddress =>
      'This is a Lightning address, which is used for payments. Flare only '
          'supports LNURL-auth.',
    _ => unsupportedLnurlMessage,
  };
}
