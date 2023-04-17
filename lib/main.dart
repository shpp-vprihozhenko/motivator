/*
shake - next
vibration
rotating & increasing quote
speak!
share
push + settings
likes + block 2 likes from one user
  app id on first run
  keep id + fcm + update if needed
  like/dislike (firebase) - block (locally), if not used - release, on press - block
scheduled send quote
catch notification, show quote fully
// todo
about
link to author + db
send me your quote!
 */

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'about.dart';
import 'firebase_options.dart';
import 'package:flutter/services.dart' show DeviceOrientation, SystemChrome, rootBundle;
import 'package:vibration/vibration.dart';
import 'package:share_extend/share_extend.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    printD('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    printD('User granted provisional permission');
  } else {
    printD('User declined or has not accepted permission');
  }

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Motivator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Quote {
  String author='', text='', id='';
  int likes = 0, dislikes = 0;

  @override
  String toString() {
    return '$author - $text';
  }
}

class Star {
  Offset pos  = const Offset(0, 0);
  Color color = Colors.white;
  double size = 5;
  double angle = 0;
  double speed = 0;
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  var db = FirebaseFirestore.instance;
  List <Quote> quotes = [];
  Quote curQuote = Quote();
  int curIdx = 0;
  List <Star> stars = [];
  List <Color> starColors = [Colors.white, Colors.white, Colors.yellowAccent, Colors.redAccent, Colors.greenAccent, Colors.blueAccent];

  var rng = Random();
  Size fieldSize = const Size(0,0);
  double topPadding = 0;

  late Animation<double> quoteAnimation;
  late AnimationController quoteAnimationController;

  bool hasGotShaking = false;
  double lastX=0, lastY=0, lastZ=0;

  double maxPi = 6*pi;

  double glTtsVolume = 0.5;
  double glTtsPitch = 1.0;
  double glTtsRate = 0.45;
  String glTtsLang = 'en-US';    // ru-RU uk-UA en-US
  FlutterTts glFlutterTts = FlutterTts();

  final GlobalKey _globalKey = GlobalKey();
  late SharedPreferences prefs;

  String appId = '', likedIds = '';

  bool isFbConnected = false;

  DateTime timeTo = DateTime.now();

  bool isUpdating = false;

  var incomingQuote = '';

  bool isSwiping = false;

  bool isPushNotificationWanted = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _readQuotes();
    _initGyroscopeListener();
    _initQuoteAnimation();
    _initTTS();
    _setupInteractedMessage();
    _initSharedPrefsAndFcm();
    Future.delayed(Duration(seconds: 20), _askForNotifications);
  }

  @override
  void dispose() {
    quoteAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppBar ab = AppBar(
      title: Row(
        children: [
          GestureDetector(
            onTap: (){
              if (kDebugMode) {
                _askForNotifications();
              }
            },
            child: const Text('Motivator+')
          ),
          Spacer(),
          GestureDetector(
            onTap: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => const About()));
            },
            child: Icon(Icons.help, size: 32, color: Colors.white,)
          )
        ],
      ),
    );
    if (fieldSize.height != MediaQuery.of(context).size.height) {
      topPadding = MediaQuery.of(context).padding.top + ab.preferredSize.height;
      _initStars();
    }
    double quoteFontSize = 32;
    if (curQuote.text.length < 70) {
      quoteFontSize = 42;
    } else if (curQuote.text.length < 120) {
      quoteFontSize = 36;
    }
    if (fieldSize.width < 370) {
      quoteFontSize = quoteFontSize/1.5;
    }
    return RepaintBoundary(
      key: _globalKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: ab,
        body: Stack(
          children: [
            ...starsWL(),
            Positioned(
              left: 0, top: 0,
              child: GestureDetector(
                onPanUpdate: (d){
                  if (isSwiping) {
                    return;
                  }
                  if (d.delta.dx < -15) {
                    _nextQuote();
                    isSwiping = true;
                    Future.delayed(Duration(seconds: 1), (){ isSwiping = false; });
                  } else if (d.delta.dx > 15) {
                    _prevQuote();
                    isSwiping = true;
                    Future.delayed(Duration(seconds: 1), (){ isSwiping = false; });
                  }
                },
                child: Container(
                  width: fieldSize.width,
                  height: fieldSize.height-topPadding-MediaQuery.of(context).padding.bottom,
                  color: Colors.deepPurple.withOpacity(0.2),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Center(
                            child: Transform.scale(
                              scale: quoteAnimation.value == 0? 1 : quoteAnimation.value/maxPi,
                              child: Transform.rotate(
                                angle: quoteAnimation.value,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(Radius.circular(24)),
                                        color: Colors.limeAccent.withOpacity(0.6),
                                      ),
                                      padding: const EdgeInsets.all(16),
                                      child: Text(curQuote.text.replaceAll('"', ''),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: quoteFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24,),
                                    Row(
                                      children: [
                                        const Expanded(flex: 1, child: SizedBox(),),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            margin: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.greenAccent,
                                              borderRadius: BorderRadius.all(Radius.circular(24)),
                                            ),
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(curQuote.author,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: quoteFontSize*0.7,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    isFbConnected?
                                      SizedBox(
                                        width: fieldSize.width,
                                        child: Container(
                                          margin: EdgeInsets.only(top: 16),
                                          padding: const EdgeInsets.only(left: 12, right: 12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              GestureDetector(
                                                onTap: (){
                                                  _markCurQuote(-1);
                                                },
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.thumb_down, color: Colors.white, size: 32,),
                                                    const SizedBox(height: 8,),
                                                    Text(curQuote.dislikes.toString(),
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: (){
                                                  _markCurQuote(1);
                                                },
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.thumb_up, color: Colors.white, size: 32,),
                                                    const SizedBox(height: 8,),
                                                    Text(curQuote.likes.toString(),
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 16
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    :
                                      const SizedBox()
                                    ,
                                  ],
                                ),
                              ),
                            ),
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: _sendToSomebody,
              child: Opacity(
                opacity: 0.5,
                child: Container(
                    margin: EdgeInsets.only(left: 34),
                    width: 54, height: 54,
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.all(Radius.circular(27)),
                    ),
                    child: const Center(child: Icon(Icons.share, size: 32, color: Colors.white,))
                ),
              ),
            ),
            isUpdating?
            const CircularProgressIndicator()
                :
            GestureDetector(
              onTap: _selectTime,
              child: Opacity(
                opacity: 0.5,
                child: Container(
                    width: 54, height: 54,
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.all(Radius.circular(27)),
                    ),
                    child: const Center(child: Icon(Icons.notifications, size: 32, color: Colors.white,))
                ),
              ),
            )
            ,
          ],
        ),
        // floatingActionButton: Row(
        //   mainAxisAlignment: MainAxisAlignment.spaceAround,
        //   children: [
        //     GestureDetector(
        //       onTap: _sendToSomebody,
        //       child: Opacity(
        //         opacity: 0.5,
        //         child: Container(
        //           margin: EdgeInsets.only(left: 34),
        //           width: 54, height: 54,
        //           decoration: const BoxDecoration(
        //             color: Colors.blueAccent,
        //             borderRadius: BorderRadius.all(Radius.circular(27)),
        //           ),
        //           child: const Center(child: Icon(Icons.share, size: 32, color: Colors.white,))
        //         ),
        //       ),
        //     ),
        //     isUpdating?
        //       const CircularProgressIndicator()
        //     :
        //       GestureDetector(
        //         onTap: _selectTime,
        //         child: Opacity(
        //           opacity: 0.5,
        //           child: Container(
        //             width: 54, height: 54,
        //             decoration: const BoxDecoration(
        //               color: Colors.blueAccent,
        //               borderRadius: BorderRadius.all(Radius.circular(27)),
        //             ),
        //             child: const Center(child: Icon(Icons.notifications, size: 32, color: Colors.white,))
        //           ),
        //         ),
        //       )
        //     ,
        //   ],
        // ),
      ),
    );
  }

  void _getFbData() async {
    printD('_getFbData');

    try {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      print("Signed in with temporary account.");
    } on FirebaseAuthException catch (e) {
      printD('FirebaseAuthException $e');
      switch (e.code) {
        case "operation-not-allowed":
          print("Anonymous auth hasn't been enabled for this project.");
          break;
        default:
          print("Unknown error.");
      }
    }

    try {
      await db.collection("quotes").get().then((event) {
        if (event.docs.isNotEmpty) {
          isFbConnected = true;
          quotes = [];
          for (var doc in event.docs) {
            var data = doc.data();
            Quote quote = Quote();
            quote.id = doc.id;
            quote.author = data["author"].trim();
            quote.text = data["quote"].trim();
            quote.likes = data["likes"] ?? 0;
            quote.dislikes = data["dislikes"] ?? 0;
            //printD("${doc.id} => ${quote.text}");
            if (quote.text.length > 10) {
              quotes.add(quote);
            }
          }
          printD('got quotes length from FB ${quotes.length}}');
        }
      });
    } catch(e) {
      printD('got err on read from FB $e');
    }
    if (incomingQuote == '') {
      curIdx = rng.nextInt(quotes.length);
      curQuote = quotes[curIdx];
    } else {
      int idx = quotes.indexWhere((quote) => quote.text == incomingQuote);
      printD('got idx for inc data $idx');
      if (idx > -1) {
        curIdx = idx;
        curQuote = quotes[idx];
      }
    }
    quoteAnimationController.forward();
  }

  void _readQuotes() async {
    String quotesStr = await rootBundle.loadString('assets/quotes_for_motivator.txt');
    List <String> quotesSource = quotesStr.split('\n');
    printD('got quotesSource ${quotesSource.length}');
    for (var element in quotesSource) {
      List <String> splitted = element.split(RegExp(r'\" [—–―-]'));
      if (splitted.length < 2) {
        printD('bad quote $element');
        continue;
      }
      Quote quote = Quote();
      quote.author = splitted[1].trim();
      quote.text = splitted[0].trim().replaceAll('"', '');
      quotes.add(quote);
    }
    printD('got quotes $quotes');
    curIdx = rng.nextInt(quotes.length);
    curQuote = quotes[curIdx];
    _getFbData();
  }

  void _initStars() {
    fieldSize = MediaQuery.of(context).size;
    printD('fieldSize $fieldSize');
    for (int i=0; i<200; i++) {
      stars.add(_getNewStar());
    }
    Future.delayed(const Duration(milliseconds: 25), _updateStars);
  }

  List <Widget> starsWL() {
    List <Widget> result = [];
    for (var star in stars) {
      result.add(
        Positioned(
          left: star.pos.dx, top: star.pos.dy,
          child: Container(
            width: star.size, height: star.size,
            decoration: BoxDecoration(
              color: star.color,
              borderRadius: BorderRadius.all(Radius.circular(star.size/2))
            ),
          ),
        )
      );
    }
    return result;
  }

  FutureOr _updateStars() {
    for (int idx=0; idx < stars.length; idx++) {
      Star star = stars[idx];
      star.pos = Offset(star.pos.dx + star.speed * cos(star.angle*3.14159/180),
                        star.pos.dy + star.speed * sin(star.angle*3.14159/180));
      if (star.pos.dx < 0 || star.pos.dx > fieldSize.width
        || star.pos.dy < 0 || star.pos.dy > fieldSize.height) {
        stars.removeAt(idx);
        stars.add(_getNewStar());
      }
    }
    setState(() {});
    Future.delayed(const Duration(milliseconds: 25), _updateStars);
  }

  Star _getNewStar() {
    Star s = Star();
    s.size = rng.nextDouble()*5+1;
    s.pos = Offset(rng.nextDouble()*fieldSize.width, rng.nextDouble()*fieldSize.height);
    s.angle = rng.nextDouble() * 360;
    s.speed = rng.nextDouble();
    s.color = starColors[rng.nextInt(starColors.length)].withOpacity(0.4+rng.nextDouble()*0.6);
    return s;
  }

  void _nextQuote() {
    curIdx++;
    if (curIdx == quotes.length) {
      curIdx = 0;
    }
    curQuote = quotes[curIdx];
    setState(() {});
    _vibration();
    quoteAnimationController.forward();
  }

  void _prevQuote() {
    curIdx--;
    if (curIdx < 0) {
      curIdx =  quotes.length - 1;
    }
    curQuote = quotes[curIdx];
    setState(() {});
    _vibration();
    quoteAnimationController.forward();
  }

  void _initGyroscopeListener() {
    gyroscopeEvents.listen((GyroscopeEvent event) {
      if (hasGotShaking) {
        return;
      }
      double xm = event.x>0? event.x:-event.x;
      double ym = event.y>0? event.y:-event.y;
      double zm = event.z>0? event.z:-event.z;
      if (xm < 0.2 && ym < 0.2 && zm < 0.2) {
        return;
      }
      printD('event gyr x ${event.x.toStringAsFixed(1)} y ${event.y.toStringAsFixed(1)} z ${event.z.toStringAsFixed(1)}');
      double limit = 0.6;
      if ((lastX > limit && event.x < limit*(-1)) || (lastX < limit*(-1) && event.x > limit)
          || (lastZ > limit && event.z < limit*(-1)) || (lastZ < limit*(-1) && event.z > limit)
      ) {
        printD('got shaking');
        _nextQuote();
        hasGotShaking = true;
        Future.delayed(const Duration(seconds: 2), (){
          hasGotShaking = false;
        });
      } else {
        if (xm > limit) {
          Future.delayed(const Duration(milliseconds: 500), (){
            lastX = 0;
          });
        }
        if (zm > limit) {
          Future.delayed(const Duration(milliseconds: 500), (){
            lastZ = 0;
          });
        }
      }
      lastX = event.x;
      lastZ = event.z;
    },
    );
  }

  void _vibration() async {
    var isVibration = await Vibration.hasVibrator();
    if (isVibration != null) {
      if (isVibration) {
        printD('here is Vibration');
        Vibration.vibrate();
      } else {
        printD('ops... No vibration');
      }
    }
  }

  void _initQuoteAnimation() {
    quoteAnimationController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this);
    quoteAnimation = Tween<double>(begin: 0, end: maxPi)
        .animate(CurvedAnimation(parent: quoteAnimationController,
        curve: Curves.fastOutSlowIn
    ))
      ..addListener(() {
        setState(() {});
      })..addStatusListener((status) async {
        if (status == AnimationStatus.completed) {
          quoteAnimationController.reset();
          //setState(() {});
          await _speak(curQuote.text);
          await Future.delayed(const Duration(milliseconds: 1000));
          await _speak(curQuote.author);
        }
      });
    quoteAnimationController.reset();
  }

  _initTTS() async {
    if (Platform.isIOS) {
      printD('isIOS!');
      await glFlutterTts.setSharedInstance(true);
      await glFlutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode
      );
    }
    await glFlutterTts.setLanguage(glTtsLang);
    await glFlutterTts.setVolume(glTtsVolume);
    await glFlutterTts.setSpeechRate(glTtsRate);
    await glFlutterTts.setPitch(glTtsPitch);
    printD('glTtsLang $glTtsLang glTtsVolume $glTtsVolume glTtsRate $glTtsRate glTtsPitch $glTtsPitch');
    await glFlutterTts.awaitSpeakCompletion(true);
  }

  _speak(String text) async {
    await glFlutterTts.stop();
    if (text.indexOf('.')>0) {
      List <String> arTexts = text.split('.');
      for (int idx=0; idx<arTexts.length; idx++) {
        await glFlutterTts.speak(arTexts[idx]);
      }
    } else {
      printD('spk $text');
      await glFlutterTts.speak(text);
    }
  }

  _sendToSomebody() async {
    try {
      RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage();
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      // glPngBytes = byteData!.buffer.asUint8List(); // bytes for Image.memory widget
      String fileName = await _writeByteToImageFile(byteData!);
      ShareExtend.shareMultiple([fileName], "image", subject: "Cool quote from Motivator");
    } catch (e) {
      printD(e.toString());
    }
  }

  Future<String> _writeByteToImageFile(ByteData byteData) async {
    Directory? dir = await getApplicationDocumentsDirectory();
    File imageFile = File("${dir.path}/tmp/${DateTime.now().millisecondsSinceEpoch}.png");
    imageFile.createSync(recursive: true);
    imageFile.writeAsBytesSync(byteData.buffer.asUint8List(0));
    return imageFile.path;
  }

  void _initFCM() async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    printD('got fcmToken $fcmToken');
    await saveTokenToDatabase(fcmToken!);
    FirebaseMessaging.instance.onTokenRefresh.listen(saveTokenToDatabase);
  }

  Future<void> _setupInteractedMessage() async {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      printD('got foreground msg $message');
      printD('got foreground notification $notification');
    });


    // Get any messages which caused the application to open from
    // a terminated state.
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    // If the message also contains a data property with a "type" of "chat",
    // navigate to a chat screen
    if (initialMessage != null) {
      _handleMessage(initialMessage, isInitial: true);
    }

    // Also handle any interaction when the app is in the background via a
    // Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message, {bool isInitial = false}) {
    printD('_handleMessage ${message.data}');
    //showAlertPage(context, 'got msg\n ${message.data}');
    incomingQuote = message.data["quote"];
    if (!isInitial) {
      int idx = quotes.indexWhere((quote) => quote.text == incomingQuote);
      printD('got idx for inc data $idx');
      if (idx > -1) {
        curIdx = idx;
        curQuote = quotes[idx];
        quoteAnimationController.forward();
      }
    }
  }

  Future<void> saveTokenToDatabase(String token) async {
    printD('saveTokenToDatabase $token for $appId');
    final userData = <String, String>{
      "appId": appId,
      "fcm": token,
    };
    await db.collection("users").doc(appId).set(userData, SetOptions(merge: true));
    printD('saveTokenToDatabase ready');
  }

  void _initSharedPrefsAndFcm() async {
    prefs = await SharedPreferences.getInstance();
    appId = prefs.getString('appId') ?? '';
    likedIds = prefs.getString('likedIds') ?? '';
    printD('got from prefs appId $appId \n likedIds $likedIds');
    if (appId == '') {
      var rng = Random();
      appId = '${DateTime.now().microsecondsSinceEpoch}_${rng.nextDouble().toString().substring(2)}';
      printD('new appId $appId');
      prefs.setString('appId', appId);
    }
    _initFCM();
    _getUserData();
  }

  void _markCurQuote(int i) async {
    if (curQuote.id == '') {
      printD('no curQuote.id');
      return;
    }
    if (likedIds.contains(curQuote.id)) {
      printD('quote is already marked');
      return;
    }
    if (i < 0) {
      curQuote.dislikes ++;
      await db.collection("quotes").doc(curQuote.id).set({"dislikes": curQuote.dislikes}, SetOptions(merge: true));
      printD('dislikes saved');
    } else {
      curQuote.likes ++;
      await db.collection("quotes").doc(curQuote.id).set({"likes": curQuote.likes}, SetOptions(merge: true));
      printD('likes saved');
    }
    likedIds+=',${curQuote.id}';
    prefs.setString('likedIds', likedIds);
    setState(() {});
  }

  _selectTime() async {
    DateTime time = timeTo;
    Size size = MediaQuery.of(context).size;
    var result = await showDialog(
        context: context,
        builder: (context) {
          return Container(
            height: size.height, width: size.width,
            color: const Color(0xFF141616).withOpacity(0.04),
            child: Column(
              children: [
                const Spacer(),
                DefaultTextStyle(
                  style: const TextStyle(color: Colors.black),
                  child: GestureDetector(
                    onPanUpdate: (d){
                      if (d.delta.dy > 15) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                        height: 389, width: size.width,
                        padding: const EdgeInsets.only(left: 16, right: 16),
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))

                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 24,),
                            Container(
                              width: 56, height: 4,
                              color: const Color(0xFFD5DEDE),
                            ),
                            const SizedBox(height: 16,),
                            Row(
                              children: [
                                Text('Select wanted push-up time',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      color: Colors.blueAccent,
                                    )
                                ),
                              ],
                            ),
                            const SizedBox(height: 16,),
                            Container(
                                padding: const EdgeInsets.all(15.0),
                                decoration: const BoxDecoration(
                                    color: Color(0xFFEDF0F9),
                                    borderRadius: BorderRadius.all(Radius.circular(16))
                                ),
                                child: TimePickerSpinner(
                                  time: time,
                                  minutesInterval: 5,
                                  is24HourMode: true,
                                  normalTextStyle: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.grey
                                  ),
                                  highlightedTextStyle: const TextStyle(
                                      fontSize: 30,
                                      color: Colors.black
                                  ),
                                  spacing: 50,
                                  itemHeight: 60,
                                  isForce2Digits: true,
                                  onTimeChange: (newTime) {
                                    setState(() {
                                      time = newTime;
                                    });
                                  },
                                )
                            ),
                            const SizedBox(height: 16,),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: (){
                                      Navigator.pop(context);
                                    },
                                    child: Container(
                                      height: 48,
                                      decoration: const BoxDecoration(
                                          color: Color(0xFFEDF0F9),
                                          borderRadius: BorderRadius.all(Radius.circular(8))
                                      ),
                                      child: const Center(
                                        child: Text('Cancel',
                                            style: TextStyle(fontFamily: 'Figtree',
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              color: Color(0xFF70768C),
                                            )
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16,),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: (){
                                      Navigator.pop(context, 'stop');
                                    },
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                          color: Colors.red[200],
                                          borderRadius: BorderRadius.all(Radius.circular(8))
                                      ),
                                      child: const Center(
                                        child: Text('Stop',
                                            style: TextStyle(fontFamily: 'Figtree',
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              color: Color(0xFF162D80),
                                            )
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16,),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: (){
                                      Navigator.pop(context, 'ok');
                                    },
                                    child: Container(
                                      height: 48,
                                      decoration: const BoxDecoration(
                                          color: Color(0xFF88A2FF),
                                          borderRadius: BorderRadius.all(Radius.circular(8))
                                      ),
                                      child: const Center(
                                        child: Text('Set',
                                            style: TextStyle(fontFamily: 'Figtree',
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                              color: Color(0xFF162D80),
                                            )
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                    ),
                  ),
                ),
              ],
            ),
          );
        }
    );
    printD('got dt $time result $result');
    if (result == null) {
      return;
    }
    isUpdating = true; setState(() {});
    if (result == 'stop') {
      await db.collection("users").doc(appId).set({"isPushesWanted": false}, SetOptions(merge: true));
      if (mounted) {
        glShowSnackBar(context, 'reminder cleared');
      }
    } else {
      await db.collection("users").doc(appId).set({"dt": time, "isPushesWanted": true}, SetOptions(merge: true));
      if (mounted) {
        glShowSnackBar(context, 'reminder set');
      }
    }
    isUpdating = false; setState(() {});
    printD('user data updated');
    timeTo = time;
    setState((){});
    return time;
  }

  void _getUserData() async {
    var doc = await db.collection("users").doc(appId).get();
    printD('got doc $doc');
    var data = doc.data();
    printD('got data $data');
    isPushNotificationWanted = data!["isPushesWanted"] ?? false;
    printD('isPushNotificationWanted $isPushNotificationWanted');
    Timestamp dt = data!["dt"];
    printD('got dt $dt');
    timeTo = DateTime.fromMillisecondsSinceEpoch(dt.millisecondsSinceEpoch);
    printD('got timeTo $timeTo');
  }

  FutureOr _askForNotifications() async {
    if (isPushNotificationWanted) {
      return;
    }
    var result = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            actionsPadding: EdgeInsets.only(bottom: 22),
            icon: Icon(Icons.help, color: Colors.lightGreen, size: 34,),
            content: Text('Do you want to receive daily quotes?', textAlign: TextAlign.center,),
            actions: [
              GestureDetector(
                onTap: (){
                  Navigator.pop(context, 'yes');
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.lightGreen[200],
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Text('yes', textScaleFactor: 1.3,)
                ),
              ),
              SizedBox(width: 60,),
              GestureDetector(
                onTap: (){
                  Navigator.pop(context);
                },
                child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text('no', textScaleFactor: 1.3,)
                ),
              ),
            ],
            actionsAlignment: MainAxisAlignment.center,
          );
        }
    );
    if (result == null) {
      return;
    }
    _selectTime();
  }
}

showAlertPage(context, String msg) async {
  await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: SelectableText(msg, textAlign: TextAlign.center,),
        );
      }
  );
}

printD(text) {
  if (kDebugMode) {
    print(text);
  }
}

glShowSnackBar(context, String msg) async {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  SnackBar snackBar = SnackBar(
    duration: const Duration(seconds: 2),
    backgroundColor: Colors.blueAccent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
    ), //StadiumBorder(),
    content: Padding(
      padding: const EdgeInsets.all(14.0),
      child: Row(
        children: [
            Text(msg,
              textAlign: TextAlign.start,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'Figtree'
              ),
            ),
        ],
      ),
    ),
  );
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
