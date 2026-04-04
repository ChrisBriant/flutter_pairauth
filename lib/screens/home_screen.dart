import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:loggy/loggy.dart';
import '../services/auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:convert';

String baseUrl = "https://192.168.1.145:8000";

enum AuthType { registration, signin }

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
  bool deviceAuthenticated = false;
  bool registrationError = false;
  AuthType authType = AuthType.registration;
  

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
    String? type = uri.queryParameters['type'];

    if (token != null && type != null) {
      logInfo("Pair token: $token");
      logInfo("Flow type: $type");
      setState(() {
        if(type == "register") {
          authType = AuthType.registration; 
        } else if(type == "signin") {
          authType = AuthType.signin;
        } else {
          registrationError = true;
        }
      });
      //Process the challenge code
      _handleProcessChallengeCode(token);
    }
  }

  Future<void> _handleProcessChallengeCode(String challengeCode) async {
    logInfo("CHALLENGE CODE ${challengeCode}");
    

    if(authType == AuthType.registration) {
      logInfo("Running registration flow");
      //Do the registration flow
      final keyPair = await AppAuth.generateKeyPair();

      //Store the private key
      await AppAuth.storePrivateKey(keyPair);

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
      logInfo("The URL is $url");
      http.post(url,headers: {
        "Content-Type": "application/json"
      },body: jsonEncode(body)).timeout(const Duration(seconds: 5)).then((res) async {
        logInfo("RESPONSE ${res.statusCode}");
        if (res.statusCode == 201) {
          final int deviceId = jsonDecode(res.body);
          await AppAuth.storeDeviceId(deviceId);
          setState( () => registered= true);
        } else {
          logError('Request failed with status: ${res.statusCode}');
          setState(() => registrationError = true);
        }
      }).catchError((err) {
        logError("Timeout error $err");
        setState(() => registrationError = true);
      });
    } else {
      //Do the sign in flow
      logInfo("Running signin flow");
      try {
        final signature = await AppAuth.signChallengeWithStoredKey(challengeCode);

        final signatureBase64 = base64Encode(signature.bytes);
        final deviceId = await AppAuth.getDeviceId();

        final Map<String,dynamic> body = {
            "challenge_code": challengeCode,
            "device_id":deviceId,
            "signature": signatureBase64,
        };

        logInfo("SIGN IN FLOW $body");

        final url = Uri.parse('$baseUrl/auth/deviceauth'); 

        http.post(url,headers: {
          "Content-Type": "application/json"
        },body: jsonEncode(body)).timeout(const Duration(seconds: 5)).then((res) async {
          logInfo("RESPONSE ${res.statusCode}");
          if (res.statusCode == 200) {
            setState( () => deviceAuthenticated = true);
          } else {
            logError('Request failed with status: ${res.statusCode}');
            setState(() => registrationError = true);
          }
        });
      } catch(err) {
        logError("Error signing in $err");
        setState(() {
          registrationError = true;
        });
      }
      


    }

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
        body: registered || deviceAuthenticated
          ? registered
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
                ElevatedButton(
                  onPressed: () => setState(() {
                    registered = false;
                  }), 
                  child: const Text("DONE")
                ),
              ]
            
            ),
          ) 
          : Center(
            child: Column(
              children: [
                const Text(
                  "Device has successfully been verified.",
                  style: TextStyle(
                    fontSize: 20
                  ),
                ),
                const Text(
                  "Please press continue in the browser.",
                  style: TextStyle(
                    fontSize: 18
                  ),
                ),
                ElevatedButton(
                  onPressed: () => setState(() {
                    deviceAuthenticated = false;
                  }), 
                  child: const Text("DONE")
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
                RadioGroup(
                  onChanged: (AuthType? val) => {
                    setState(() {
                      authType = val!;
                    })
                  },
                  groupValue: authType,
                  child: Column(
                    children: [
                      RadioListTile<AuthType>(
                        title: Text("Register"),
                        value: AuthType.registration,
                      ),
                      RadioListTile<AuthType>(
                        title: Text("Sign In"),
                        value: AuthType.signin,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _handleProcessChallengeCode(codeInput.text), 
                  child: const Text("Send")
                ),
                registrationError
                ? const Text("Unable to authenticate the device. Please try again from the app",
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

