import 'dart:convert';
import 'package:bitcoin_bech32_ng/bitcoin_bech32_ng.dart';

String decodeLnurlToUrl(String lnurl) {
  final bech32Data = bech32.decode(lnurl, lnurl.length);
  final bytes = convertBits(bech32Data.data, 5, 8, false);
  return utf8.decode(bytes);
}

Uri decodeLnurlToUri(String lnurl) {
  return Uri.parse(decodeLnurlToUrl(lnurl));
}

List<int> convertBits(
    List<int> data,
    int fromBits,
    int toBits,
    bool pad,
    ) {
  int acc = 0;
  int bits = 0;
  final result = <int>[];
  final maxv = (1 << toBits) - 1;
  final maxAcc = (1 << (fromBits + toBits - 1)) - 1;

  for (final value in data) {
    if (value < 0 || (value >> fromBits) != 0) {
      throw FormatException('Invalid value: $value');
    }

    acc = ((acc << fromBits) | value) & maxAcc;
    bits += fromBits;

    while (bits >= toBits) {
      bits -= toBits;
      result.add((acc >> bits) & maxv);
    }
  }

  if (pad) {
    if (bits > 0) {
      result.add((acc << (toBits - bits)) & maxv);
    }
  } else {
    if (bits >= fromBits) {
      throw const FormatException('Excess padding');
    }
    if (((acc << (toBits - bits)) & maxv) != 0) {
      throw const FormatException('Non-zero padding');
    }
  }

  return result;
}