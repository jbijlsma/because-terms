import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';
import 'dart:html';

import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:screenshot/screenshot.dart';
import 'package:email_validator/email_validator.dart';

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Because - terms of engagement',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(91, 198, 194, 1)),
        useMaterial3: true,
      ),
      home: const MyHomePage(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
                image: AssetImage('assets/because_logo.webp'),
                height: 200,
                width: 200),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final Widget title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool? _isAgreeChecked = false;
  String? _error;

  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();

  // When a verification email was sent, this keeps track of the email address
  String? _email;
  bool _isEmailValid = true;

  String? _submitValidationErrors;

  final ScreenshotController _screenshotController = ScreenshotController();

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 5,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _signatureController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<String> _saveWaiverToStorage(String email, Uint8List imgBytes) {
    final storageRef = FirebaseStorage.instance.ref();
    final waiverRef = storageRef.child("waivers/$email.png");
    final uploadTask = waiverRef.putData(
        imgBytes,
        SettableMetadata(
          contentType: "image/png",
        ));

    final completer = Completer<String>();

    // Listen for state changes, errors, and completion of the upload.
    uploadTask.snapshotEvents.listen((TaskSnapshot taskSnapshot) async {
      switch (taskSnapshot.state) {
        case TaskState.running:
          final progress =
              100.0 * (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes);
          print("Upload is $progress% complete.");
          break;
        case TaskState.paused:
          print("Upload is paused.");
          break;
        case TaskState.canceled:
          print("Upload was canceled");
          break;
        case TaskState.error:
          // Handle unsuccessful uploads
          completer.completeError("Upload failed");
          break;
        case TaskState.success:
          // Handle successful uploads on complete
          final downloadUrl = await taskSnapshot.ref.getDownloadURL();
          print("DownloadURL: $downloadUrl");
          completer.complete(downloadUrl);
          break;
      }
    });

    return completer.future;
  }

  Future<void> _saveWaiverToFirebaseStorage(
      String email, String waiverDownloadUrl) async {
    final db = FirebaseFirestore.instance;
    final waiver = <String, dynamic>{
      "email": email,
      "downloadUrl": waiverDownloadUrl
    };

    // Add a new document with a generated ID
    final doc = await db.collection("waivers").add(waiver);
    print('DocumentSnapshot added with ID: ${doc.id}');

    // await FileSaver.instance.saveFile(
    //     name: 'waiver',
    //     bytes: capturedScreenshotImageBytes,
    //     mimeType: MimeType.png);
  }

  Future<void> _saveWaiver(Uint8List imgBytes) async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final email = currentUser.email!;

    final downloadUrl = await _saveWaiverToStorage(email, imgBytes);

    await _saveWaiverToFirebaseStorage(email, downloadUrl);
  }

  Widget _createScreenShotWidget(Uint8List signatureImgBytes, String fullName) {
    return Container(
      width: 800,
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  color: const Color.fromRGBO(91, 198, 194, 1),
                  child: const Image(
                    image: AssetImage('assets/because_logo.webp'),
                    height: 100,
                    width: 200,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [..._buildTextWidgets()],
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'I agree to the Terms of Engagement',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
                child: Icon(
                  Icons.check,
                  color: Colors.black,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            fullName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 26),
          ),
          Image.memory(signatureImgBytes)
        ],
      ),
    );
  }

  Future<String?> _trySignInWithEmailLink() async {
    if (FirebaseAuth.instance.currentUser != null) {
      print(
          'Firebase user already signed in: ${FirebaseAuth.instance.currentUser?.email}');
      return FirebaseAuth.instance.currentUser?.email;
    }

    final emailLink = window.location.href;

    if (FirebaseAuth.instance.isSignInWithEmailLink(emailLink)) {
      try {
        final uri = Uri.parse(emailLink);
        final email = uri.queryParameters['email']!;

        final userCredential = await FirebaseAuth.instance
            .signInWithEmailLink(email: email, emailLink: emailLink);

        final userEmail = userCredential.user?.email;
        print('Firebase user email: $userEmail');

        return userEmail;
      } catch (error) {
        setState(() {
          _error = error.toString();
        });
        return "";
      }
    }

    return "";
  }

  Widget _buildVerifyEmailRow() {
    return Column(
      children: [
        if (!_isEmailValid)
          const Column(
            children: [
              Text(
                'Please provide a valid email address',
                style: TextStyle(color: Colors.red, fontSize: 16),
              )
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = _emailController.text;

                final isEmailValid = EmailValidator.validate(email);

                if (!isEmailValid) {
                  setState(() {
                    _isEmailValid = false;
                  });

                  return;
                }

                var acs = ActionCodeSettings(
                    url: '${window.location.href}?email=$email',
                    handleCodeInApp: true);

                FirebaseAuth.instance
                    .sendSignInLinkToEmail(
                        email: email, actionCodeSettings: acs)
                    .catchError((onError) {
                  setState(() {
                    _error = onError;
                  });
                }).then((value) {
                  setState(() {
                    _email = email;
                    _isEmailValid = true;
                  });
                });
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmailVerifiedColumn(email) {
    return Column(
      children: [
        Text(
          "Welcome ${email ?? 'guest'} \n Your email was verified",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            window.location.replace(window.location.href.split('?')[0]);
          },
          child: const Text('Use a different email address'),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'I agree to the Terms of Engagement',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Transform.scale(
              scale: 1.5,
              child: Checkbox(
                key: const Key('agree'),
                checkColor: Colors.white,
                fillColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.disabled)) {
                    return const Color.fromRGBO(91, 198, 194, 1)
                        .withOpacity(.32);
                  }
                  return const Color.fromRGBO(91, 198, 194, 1);
                }),
                value: _isAgreeChecked,
                onChanged: (bool? value) {
                  setState(() {
                    _isAgreeChecked = value;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 300,
          child: TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Fullname',
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Your Signature',
            style: TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        Signature(
          controller: _signatureController,
          width: 200,
          height: 150,
          backgroundColor: const Color.fromARGB(255, 148, 221, 219),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              color: const Color.fromARGB(255, 148, 221, 219),
              onPressed: () {
                setState(() => _signatureController.undo());
              },
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              color: const Color.fromARGB(255, 148, 221, 219),
              onPressed: () {
                setState(() => _signatureController.redo());
              },
              tooltip: 'Redo',
            ),
            //CLEAR CANVAS
            IconButton(
              key: const Key('clear'),
              icon: const Icon(Icons.clear),
              color: const Color.fromARGB(255, 148, 221, 219),
              onPressed: () {
                setState(() => _signatureController.clear());
              },
              tooltip: 'Clear',
            )
          ],
        ),
        const SizedBox(height: 40),
        if (_submitValidationErrors != null)
          Column(
            children: [
              Text(
                _submitValidationErrors!,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 20)
            ],
          ),
        Transform.scale(
          scale: 1.2,
          child: ElevatedButton(
            onPressed: () async {
              String? validationMessage;

              if (_isAgreeChecked != true) {
                validationMessage = "Please agree to the Terms of Engagement";
              }

              if (validationMessage == null && _fullNameController.text == '') {
                validationMessage = "Please provide your full name";
              }

              if (validationMessage == null && _signatureController.isEmpty) {
                validationMessage = "Please put your signature";
              }

              if (validationMessage != null) {
                setState(() {
                  _submitValidationErrors = validationMessage;
                });

                return;
              }

              final signatureImgBytes = await _signatureController.toPngBytes(
                width: 200,
                height: 150,
              );

              final capturedScreenshotImageBytes = await _screenshotController
                  .captureFromWidget(_createScreenShotWidget(
                      signatureImgBytes!, _fullNameController.text));

              await _saveWaiver(capturedScreenshotImageBytes);
            },
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildTextWidgets() {
    return <Widget>[
      const Text(
        'Terms of Engagement',
        style: TextStyle(
            color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
      ),
      const SizedBox(height: 20),
      RichText(
        text: const TextSpan(
          // Note: Styles for TextSpans must be explicitly defined.
          // Child text spans will inherit styles from parent
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
          ),
          children: <TextSpan>[
            TextSpan(
              text:
                  'I have read and understood the terms of engagement outlined below. I acknowledge that participating in (sports) activities and related events, organized, or sponsored by Because – Sports to Support (referred to as "',
            ),
            TextSpan(
              text: 'Because',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text:
                  '") may involve high-intensity physical movements and carry inherent risks, including accidents and injury. I understand that the activities held by ',
            ),
            TextSpan(
              text: 'Because',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text:
                  ' are not a substitute for medical attention or treatment and may not be suitable for individuals with certain medical conditions.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      RichText(
        text: const TextSpan(
          // Note: Styles for TextSpans must be explicitly defined.
          // Child text spans will inherit styles from parent
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
          ),
          children: <TextSpan>[
            TextSpan(
              text:
                  'I represent and warrant that I am in good health and physically and mentally capable of participating in the ',
            ),
            TextSpan(
              text: 'Because',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text:
                  ' activities. I take full responsibility for consulting with a physician before engaging in the activities. I willingly and knowingly accept all risks associated with participating in the activities, including any loss, claim, injury, damage, or liability, whether known or unknown, that may arise from my participation.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      RichText(
        text: const TextSpan(
          // Note: Styles for TextSpans must be explicitly defined.
          // Child text spans will inherit styles from parent
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
          ),
          children: <TextSpan>[
            TextSpan(
              text:
                  'During my involvement in the activities, I assume any risk involved and release ',
            ),
            TextSpan(
              text: 'Because',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text:
                  ', its coaches, its volunteers, and its representatives from any and all liability for any harm or injury I may sustain. I agree to indemnify and hold ',
            ),
            TextSpan(
              text: 'Because',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text:
                  ' harmless from any loss, cost, claim, injury, damage, or liability incurred during my participation, including the use of the facilities or equipment.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      RichText(
        text: const TextSpan(
          // Note: Styles for TextSpans must be explicitly defined.
          // Child text spans will inherit styles from parent
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
          ),
          children: <TextSpan>[
            TextSpan(
              text:
                  'By signing below, I acknowledge that I have read and understood this assumption of risk, release, and waiver of liability. I voluntarily and freely consent to the terms and conditions stated above. I affirm that I have the freedom to decide whether to participate in the activities held by ',
            ),
            TextSpan(
              text: 'Because',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text:
                  ' and warrant that I have no medical condition that would hinder my full participation.',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      RichText(
        text: const TextSpan(
          // Note: Styles for TextSpans must be explicitly defined.
          // Child text spans will inherit styles from parent
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.black,
          ),
          children: <TextSpan>[
            TextSpan(
              text: 'By participation in ',
            ),
            TextSpan(
              text: 'Because',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text:
                  ' activities, you agree to the collection, use, and sharing of your personal data for activities-related communication and organization. This includes your contact information and any health details necessary for your participation. You can withdraw consent by emailing cathiecocqueel@because-sport.com. We\'ll retain your data as required for activities administration. We may also use photos and videos taken during the activities for promotional and marketing purposes; let us know if you prefer not to be included.',
            ),
          ],
        ),
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: widget.title,
      ),
      body: SingleChildScrollView(
        child: Screenshot(
          controller: _screenshotController,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  ..._buildTextWidgets(),
                  const SizedBox(height: 20),
                  if (_error != null)
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  if (_email != null)
                    Text(
                      'We sent a verification email to $_email\n Click on the link in the email to continue ..',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.green),
                    ),
                  if (_email == null)
                    FutureBuilder(
                      future: _trySignInWithEmailLink(),
                      builder: (context, snapshot) {
                        final email = snapshot.data;

                        if (email == '') {
                          return _buildVerifyEmailRow();
                        }

                        return _buildEmailVerifiedColumn(email);
                      },
                    ),
                ],
              ),
            ),
          ), // This trailing comma makes auto-formatting nicer for build methods.
        ),
      ),
    );
  }
}
