import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';


class AppAuth {


  static final storage = FlutterSecureStorage();

  static final algorithm = Ed25519();

  static Future<KeyPair> generateKeyPair() async {
    return await algorithm.newKeyPair();
  }


  static Future<List<int>> getPublicKey(KeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey() as SimplePublicKey;
    return publicKey.bytes;
  }

  static Future<Signature> signChallenge(KeyPair keyPair, String challenge) async {
    final signature = await algorithm.sign(
      challenge.codeUnits,
      keyPair: keyPair,
    );
    return signature;
  }


  static String toBase64(List<int> bytes) {
    return base64Encode(bytes);
  }

  static Future<void> storePrivateKey(KeyPair keyPair) async {
    final privateKey = await keyPair.extract();
    final privateKeyData = privateKey as SimpleKeyPairData;
    final privateKeyBytes = privateKeyData.bytes;

    await storage.write(
      key: 'private_key',
      value: base64Encode(privateKeyBytes),
    );
  }

  static Future<String> getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.manufacturer} ${androidInfo.model}';
    } else {
      return 'Unknown Device';
    }
  }


}