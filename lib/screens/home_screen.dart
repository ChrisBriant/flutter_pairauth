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
  late String? deviceIdDisplay = null;
  

  void _handleDeepLink() async {
    //Get the device ID for display
    int deviceId= await AppAuth.getDeviceId();
    deviceIdDisplay = deviceId.toString();

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
    logInfo("Pair token: $token");
    logInfo("Flow type: $type");

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
          title: const Text("Pair Auth - Authenticator"),
          actions: [
            IconButton(
              onPressed: () => {
                showDialog(
                  context: context, 
                  builder: (context) => AlertDialog(
                    title: const Text("Info"),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "This is a demo authenticator application used to demonstrate device verification.",
                          style: TextStyle(fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Purpose",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          "It serves as a secure authentication method for both account registration and sign-in processes.",
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "How to verify:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text("1. Scan the QR code shown on the web app after signing in or registering."),
                        const Text("2. Or, enter the code manually using the 'Enter Code Manually' field."),
                        const SizedBox(height: 16),
                        const Text(
                          "Demo Environment",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          "You can access the demo front-end application at:",
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "pairauth.chrisbriant.uk",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(), 
                        child: const Text("Ok")
                      )
                    ],
                  )
                )
              }, 
              icon: Icon(Icons.info)
            )
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 20,),
              Image.asset(
                'assets/logo.png',
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * .3,
              ),
              deviceIdDisplay != null ? Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Text(
                  'Device Id : $deviceIdDisplay',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: const Color.fromARGB(255, 115, 160, 43),
                  ),
                  
                ),
              ) : const SizedBox(),
              Container(
                margin: EdgeInsets.all(20),
                child: registered || deviceAuthenticated
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
                        Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            border: Border.all(
                                  color: const Color.fromARGB(255, 115, 160, 43),
                                  width: 6.0,
                            ),
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 115, 160, 43),
                              borderRadius: BorderRadius.circular(10)
                              
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  "Enter Code Manually", 
                                  style: TextStyle(
                                    fontSize: 20,
                                    color: Colors.white
                                  ),
                                ),
                                TextField(
                                  controller: codeInput,
                                  style: TextStyle(
                                    color: Colors.white
                                  ),
                                  decoration: InputDecoration(
                                    enabledBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white, 
                                        width: 3.0, // Makes the line thicker
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white, 
                                        width: 3.0, // Makes the line thicker
                                      ),
                                    ),
                                  ),
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
                                        fillColor: WidgetStateProperty.all(Colors.white),
                                        title: Text("Register", style: TextStyle(color: Colors.white),),
                                        value: AuthType.registration,
                                      ),
                                      RadioListTile<AuthType>(
                                        fillColor: WidgetStateProperty.all(Colors.white),
                                        title: Text("Sign In", style: TextStyle(color: Colors.white),),
                                        value: AuthType.signin,
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () => _handleProcessChallengeCode(codeInput.text), 
                                  child: const Text("Send")
                                ),
                              ],
                            ),
                          ),
                        ),

                        registrationError
                        ? Container(
                          margin: EdgeInsets.symmetric(vertical: 10),
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100
                          ),
                          child: const Text("Unable to authenticate the device. Please try again from the app.",
                            style: TextStyle(
                              color: Colors.red
                            ),
                          ),
                        ) : const SizedBox()
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

