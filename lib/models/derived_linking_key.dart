import 'dart:typed_data';

class DerivedLinkingKey {
  final BigInt privateKey;
  final Uint8List compressedPublicKey;

  DerivedLinkingKey({
    required this.privateKey,
    required this.compressedPublicKey,
  });
}