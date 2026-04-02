import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:loggy/loggy.dart';
import '../services/auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:convert';

String baseUrl = "http://10.0.2.2:8000";


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
  bool registered = false;
  bool registrationError = false;
  

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

    final url = Uri.parse('$baseUrl/auth/registerdevice'); 
    final Map<String,dynamic> body = {
        "challenge_code": challengeCode,
        "public_key":publicKeyBase64,
        "signature": signatureBase64,
        "device_name": deviceName
    };
    http.post(url,headers: {
      "Content-Type": "application/json"
    },body: jsonEncode(body)).timeout(const Duration(seconds: 5)).then((res) {
      logInfo("RESPONSE ${res.statusCode}");
      if (res.statusCode == 201) {
        setState( () => registered= true);
      } else {
        logError('Request failed with status: ${res.statusCode}');
        setState(() => registrationError = true);
      }
      // if (res.statusCode == 200) {
      //   final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      //   logInfo('IDP DATA $data');
      //   setState(() {
      //     loading = false;
      //     idpList = data;
      //   });
      // } else {
      //   logError('Request failed with status: ${res.statusCode}');
      // }
    });
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
        body: registered
          ? Center(
            child: Column(
              children: [
                const Text(
                  "You have successfully registered",
                  style: TextStyle(
                    fontSize: 20
                  ),
                ),
                const Text(
                  "Please press continue in the browser to sign in.",
                  style: TextStyle(
                    fontSize: 18
                  ),
                ),
              ]
            
            ),
          ) 
        
          : Column(
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
                ),
                registrationError
                ? const Text("Registration Failed",
                  style: TextStyle(
                    color: Colors.red
                  ),
                ) : const SizedBox()
              ],
            )
          ],
        ),
      );
  }
}

