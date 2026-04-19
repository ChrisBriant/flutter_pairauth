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

  //For singing with existing private key
  static Future<KeyPair> loadPrivateKey() async {
    final encoded = await storage.read(key: 'private_key');
    if (encoded == null) {
      throw Exception('No private key found');
    }
    final privateKeyBytes = base64Decode(encoded);

    // Reconstruct key pair from private key seed
    return algorithm.newKeyPairFromSeed(privateKeyBytes);
  }
  
  static Future<Signature> signChallengeWithStoredKey(String challenge) async {
    final keyPair = await loadPrivateKey();
    final signature = await algorithm.sign(
      utf8.encode(challenge), // convert string to bytes
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

  static Future<void> storeDeviceId(int deviceId) async {
    await storage.write(
      key: 'device_id',
      value: deviceId.toString(),
    );
  }

  static Future<int> getDeviceId() async {
      String? deviceId = await storage.read(key: "device_id");
      if(deviceId != null) {
        return int.parse(deviceId); 
      }
      throw Exception("Unable to retrieve device ID");
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

  static Future<void> clearStorage() async {
    await storage.deleteAll();
  }


}