import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:loggy/loggy.dart';
import '../services/auth.dart';
import 'dart:convert';


class HomeScreen extends StatefulWidget {
  static const String routeName = '/homescreen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}




class _HomeScreenState extends State<HomeScreen> {
  final AppLinks _appLinks = AppLinks();
  String? tokenState;
  late TextEditingController codeInput;

  void _handleDeepLink() async {

    // If app opened from closed state
    final uri = await _appLinks.getInitialLink();

    if (uri != null) {
      _processUri(uri);
    }

    // If app already running
    _appLinks.uriLinkStream.listen((uri) {
      _processUri(uri);
    });
  }

  void _processUri(Uri uri) {
    logInfo("Deep link received: $uri");

    String? token = uri.queryParameters['token'];

    if (token != null) {
      logInfo("Pair token: $token");
      setState(() {
        tokenState = token;
      });


      // Send to backend to approve login
    }
  }

  Future<void> _handleProcessChallengeCode(String challengeCode) async {
    logInfo("CHALLENGE CODE ${challengeCode}");

    final keyPair = await AppAuth.generateKeyPair();

    final publicKeyBytes = await AppAuth.getPublicKey(keyPair);
    final signature = await AppAuth.signChallenge(keyPair, challengeCode);

    final publicKeyBase64 = base64Encode(publicKeyBytes);
    final signatureBase64 = base64Encode(signature.bytes);
    final deviceName =  await AppAuth.getDeviceName();

    logInfo("Public key : $publicKeyBase64");
    logInfo("Signature : $signatureBase64" );
    logInfo("Device name : $deviceName");
  }

  @override
  void initState() {
    super.initState();
    codeInput = TextEditingController();
    _handleDeepLink();
  }

  @override
  void dispose() {
    codeInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Pair Auth"),
        ),
        body: Column(
          children: [
            tokenState != null 
            ? Text(tokenState!) 
            : Column(
              children: [
                const Text("Enter Code Manually:"),
                TextField(
                  controller: codeInput,
                ),
                ElevatedButton(
                  onPressed: () => _handleProcessChallengeCode(codeInput.text), 
                  child: const Text("Send")
                )
              ],
            )
          ],
        ),
      );
  }
}

