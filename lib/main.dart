import 'dart:async';
import 'dart:html';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import './firebase_options.dart';
import './pdf_builder.dart' as pb;
import './wiget_builder.dart' as wb;
import './common_widgets.dart' as cw;

import 'package:email_validator/email_validator.dart';
import 'package:signature/signature.dart';
import 'package:pdf/widgets.dart' as pw;

const uid = Uuid();

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
      title: 'Because - Terms of Engagement',
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
              width: 200,
            ),
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
  static const becauseColor = Color.fromARGB(255, 148, 221, 219);
  static const becauseColorDarker = Color.fromARGB(255, 32, 196, 191);

  bool _waiverSubmitting = false;
  String _waiverSubmitMessage = '';
  String _waiverDownloadUrl = '';
  bool _waiverSubmitted = false;

  bool? _isAgreeChecked = false;
  bool? _isAgeConfirmed = false;
  String? _error;

  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();

  // When a verification email was sent, this keeps track of the email address
  String? _email;
  bool _isEmailValid = true;

  String? _submitValidationErrors;

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

  cw.Document _generateDocument(int titleFontSize, int textFontSize) {
    return cw.Document('Terms of Engagement and Liability Waiver', 20, 8, [
      cw.Paragraph([
        cw.Txt(
            'I acknowledge that participation in activities organized by Because - Sports to Support ("',
            'normal'),
        cw.Txt('Because', 'bold'),
        cw.Txt(
            '") inherently involves risks, including the potential for accidents and injuries. I confirm that I am in good health and fully capable of participating in these activities. By signing this agreement, I voluntarily accept all related risks and agree to release and hold harmless ',
            'normal'),
        cw.Txt('Because', 'bold'),
        cw.Txt(
            ', its coaches, and representatives from any liability for harm or loss that may occur. Additionally, I agree to indemnify ',
            'normal'),
        cw.Txt('Because', 'bold'),
        cw.Txt(
            ' against any losses that may arise from my participation. I confirm my understanding and acceptance of these terms through my signature below. I also consent to the use of my personal data for communication purposes and authorize the use of my images in ',
            'normal'),
        cw.Txt('Because\'s', 'bold'),
        cw.Txt(' promotional materials.', 'normal'),
      ]),
    ], [
      cw.TxtStyle('title',
          color: Colors.black, fontSize: titleFontSize, isBold: true),
      cw.TxtStyle('normal', color: Colors.black, fontSize: textFontSize),
      cw.TxtStyle('bold',
          color: Colors.black, fontSize: textFontSize, isBold: true),
    ]);
  }

  Future<String> _saveWaiverToStorage(String email, Uint8List imgBytes) {
    final storageRef = FirebaseStorage.instance.ref();
    final waiverRef = storageRef.child("waivers/${uid.v4()}.pdf");
    final uploadTask = waiverRef.putData(
        imgBytes,
        SettableMetadata(
          contentType: "application/pdf",
        ));

    final completer = Completer<String>();

    // Listen for state changes, errors, and completion of the upload.
    uploadTask.snapshotEvents.listen((TaskSnapshot taskSnapshot) async {
      switch (taskSnapshot.state) {
        case TaskState.running:
          final progress =
              100.0 * (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes);
          setState(() {
            _waiverSubmitMessage = 'Uploading waiver ($progress)';
          });
          break;
        case TaskState.paused:
          break;
        case TaskState.canceled:
          break;
        case TaskState.error:
          // Handle unsuccessful uploads
          completer.completeError("Upload failed");
          break;
        case TaskState.success:
          // Handle successful uploads on complete
          final downloadUrl = await taskSnapshot.ref.getDownloadURL();
          completer.complete(downloadUrl);
          break;
      }
    });

    return completer.future;
  }

  Future<void> _saveWaiverToFirebaseStorage(
      String email, String waiverDownloadUrl) async {
    final currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;
    final waiver = <String, dynamic>{
      "createdByUid": currentUserUid,
      "email": email,
      "fullName": _fullNameController.text,
      "downloadUrl": waiverDownloadUrl
    };

    await db.collection("waivers").doc(currentUserUid).set(waiver);
  }

  Future<pw.Document> _createPdfWaiver(Uint8List signatureImgBytes) async {
    final doc = _generateDocument(16, 13);

    doc.children.add(cw.Spacer(10));
    doc.children.add(cw.CheckBox('I agree to the Terms of Engagement', 'bold'));
    doc.children.add(cw.Spacer(10));
    doc.children
        .add(cw.CheckBox('I confirm I am at least 18 years old', 'bold'));
    doc.children.add(cw.Spacer(10));
    doc.children.add(cw.Txt(_fullNameController.text, 'bold'));
    doc.children.add(cw.Img(signatureImgBytes));

    var pdf = pb.PdfBuilder(doc);

    return pdf.build();
  }

  Future<void> _saveWaiver() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final email = currentUser.email!;

    try {
      setState(() {
        _waiverSubmitting = true;
        _waiverSubmitMessage = 'Submitting waiver ..';
      });

      final signatureImgBytes = await _signatureController.toPngBytes(
        width: 200,
        height: 150,
      );

      final pdf = await _createPdfWaiver(signatureImgBytes!);
      final pdfBytes = await pdf.save();

      final downloadUrl = await _saveWaiverToStorage(email, pdfBytes);

      setState(() {
        _waiverDownloadUrl = downloadUrl;
      });

      await _saveWaiverToFirebaseStorage(email, downloadUrl);

      setState(() {
        _waiverSubmitted = true;
      });

      await FirebaseAuth.instance.signOut();
    } catch (err) {
      setState(() {
        _error = "Failed to submit waiver ..";
      });
    } finally {
      _waiverSubmitting = false;
    }
  }

  Future<String?> _trySignInWithEmailLink() async {
    if (FirebaseAuth.instance.currentUser != null) {
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
        // print('Firebase user email: $userEmail');

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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'I confirm I am at least 18 years old',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Transform.scale(
              scale: 1.5,
              child: Checkbox(
                key: const Key('confirmAge'),
                checkColor: Colors.white,
                fillColor: MaterialStateProperty.resolveWith<Color>(
                    (Set<MaterialState> states) {
                  if (states.contains(MaterialState.disabled)) {
                    return const Color.fromRGBO(91, 198, 194, 1)
                        .withOpacity(.32);
                  }
                  return const Color.fromRGBO(91, 198, 194, 1);
                }),
                value: _isAgeConfirmed,
                onChanged: (bool? value) {
                  setState(() {
                    _isAgeConfirmed = value;
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
          backgroundColor: becauseColor,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              color: becauseColor,
              onPressed: () {
                setState(() => _signatureController.undo());
              },
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              color: becauseColor,
              onPressed: () {
                setState(() => _signatureController.redo());
              },
              tooltip: 'Redo',
            ),
            //CLEAR CANVAS
            IconButton(
              key: const Key('clear'),
              icon: const Icon(Icons.clear),
              color: becauseColor,
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
            onPressed: _waiverSubmitting
                ? null
                : () async {
                    String? validationMessage;

                    if (_isAgreeChecked != true) {
                      validationMessage =
                          "Please agree to the Terms of Engagement";
                    }

                    if (_isAgeConfirmed != true) {
                      validationMessage =
                          "Please confirm you are at least 18 years old";
                    }

                    if (validationMessage == null &&
                        _fullNameController.text == '') {
                      validationMessage = "Please provide your full name";
                    }

                    if (validationMessage == null &&
                        _signatureController.isEmpty) {
                      validationMessage = "Please put your signature";
                    }

                    if (validationMessage != null) {
                      setState(() {
                        _submitValidationErrors = validationMessage;
                      });

                      return;
                    }

                    await _saveWaiver();
                  },
            child: const Text('Submit'),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionalWidget() {
    if (_waiverSubmitted) {
      const textStyle = TextStyle(fontSize: 16, color: becauseColorDarker);
      const textStyleBold = TextStyle(
          fontSize: 16, color: becauseColorDarker, fontWeight: FontWeight.bold);

      return Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              const TextSpan(
                text: 'Thank you!\n',
                style: textStyleBold,
              ),
              const TextSpan(
                text: 'You can view your waiver ',
                style: textStyle,
              ),
              TextSpan(
                text: 'here',
                style: textStyleBold,
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    launchUrl(Uri.parse(_waiverDownloadUrl));
                  },
              ),
            ],
          ),
        ),
      );
    }

    if (_waiverSubmitting) {
      return Text(
        _waiverSubmitMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: becauseColorDarker),
      );
    }

    if (_email != null) {
      return Text(
        'We sent a verification email to $_email\nClick on the link in the email to continue ..\n Check your Spam folder if you don\'t see it',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: becauseColorDarker),
      );
    }

    return FutureBuilder(
      future: _trySignInWithEmailLink(),
      builder: (context, snapshot) {
        final email = snapshot.data;

        if (email == '') {
          return _buildVerifyEmailRow();
        }

        return _buildEmailVerifiedColumn(email);
      },
    );
  }

  List<Widget> _buildTextWidgets() {
    // return List.empty();
    return wb.WidgetBuilder(_generateDocument(22, 16)).build();
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
                _buildConditionalWidget()
              ],
            ),
          ), // This trailing comma makes auto-formatting nicer for build methods.
        ),
      ),
    );
  }
}
