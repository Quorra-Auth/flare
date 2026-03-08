import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39_plus/bip39_plus.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_identity.dart';

class IdentityService {
  static const _storageKey = 'lnurl_auth_identities';

  final FlutterSecureStorage secureStorage;

  const IdentityService(this.secureStorage);

  Future<List<AuthIdentity>> getIdentities() async {
    final raw = await secureStorage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw Exception('Invalid identity storage');
    }

    return decoded
        .map((e) => AuthIdentity.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveIdentities(List<AuthIdentity> identities) async {
    final raw = jsonEncode(identities.map((e) => e.toJson()).toList());
    await secureStorage.write(key: _storageKey, value: raw);
  }

  Future<AuthIdentity> createIdentity({required String name}) async {
    final mnemonic = bip39.generateMnemonic();
    final identity = AuthIdentity(
      id: _randomId(),
      name: name,
      mnemonic: mnemonic,
      createdAt: DateTime.now().toUtc(),
    );

    final identities = await getIdentities();
    identities.add(identity);
    await saveIdentities(identities);
    return identity;
  }

  Future<AuthIdentity> restoreIdentity({
    required String name,
    required String mnemonic,
  }) async {
    final normalized = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    if (!bip39.validateMnemonic(normalized)) {
      throw Exception('Invalid BIP39 mnemonic');
    }

    final identities = await getIdentities();

    final identity = AuthIdentity(
      id: _randomId(),
      name: name,
      mnemonic: normalized,
      createdAt: DateTime.now().toUtc(),
    );

    identities.add(identity);
    await saveIdentities(identities);
    return identity;
  }

  Future<void> deleteIdentity(String id) async {
    final identities = await getIdentities();
    identities.removeWhere((i) => i.id == id);
    await saveIdentities(identities);
  }

  Future<void> renameIdentity(String id, String newName) async {
    final identities = await getIdentities();
    final index = identities.indexWhere((i) => i.id == id);
    if (index == -1) {
      throw Exception('Identity not found');
    }

    final current = identities[index];
    identities[index] = AuthIdentity(
      id: current.id,
      name: newName,
      mnemonic: current.mnemonic,
      createdAt: current.createdAt,
    );

    await saveIdentities(identities);
  }

  Future<Uint8List> mnemonicToSeedBytes(String mnemonic) async {
    final seed = bip39.mnemonicToSeed(mnemonic);
    return Uint8List.fromList(seed);
  }

  String _randomId() {
    final random = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      16,
          (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}