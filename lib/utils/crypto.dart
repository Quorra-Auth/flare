import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';

Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

BigInt bytesToBigInt(Uint8List bytes) {
  return BigInt.parse(hex.encode(bytes), radix: 16);
}

List<int> bigIntToBytes(BigInt value) {
  if (value == BigInt.zero) {
    return [0];
  }

  var hexStr = value.toRadixString(16);
  if (hexStr.length.isOdd) {
    hexStr = '0$hexStr';
  }
  return hex.decode(hexStr);
}

Uint8List encodeDerSignature(BigInt r, BigInt s) {
  final rBytes = encodeDerInteger(r);
  final sBytes = encodeDerInteger(s);

  final sequence = <int>[
    0x30,
    rBytes.length + sBytes.length,
    ...rBytes,
    ...sBytes,
  ];

  return Uint8List.fromList(sequence);
}

List<int> encodeDerInteger(BigInt value) {
  if (value < BigInt.zero) {
    throw Exception('DER integer must be non-negative');
  }

  var bytes = bigIntToBytes(value);

  while (bytes.length > 1 && bytes[0] == 0x00 && (bytes[1] & 0x80) == 0) {
    bytes = bytes.sublist(1);
  }

  if (bytes.isEmpty) {
    bytes = [0x00];
  }

  if ((bytes[0] & 0x80) != 0) {
    bytes = [0x00, ...bytes];
  }

  return [
    0x02,
    bytes.length,
    ...bytes,
  ];
}