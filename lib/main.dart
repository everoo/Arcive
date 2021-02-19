import 'dart:io';
import 'dart:math';

import 'package:arcive/Globals.dart';
import 'package:arcive/Pages/HomePage.dart';
import 'package:arcive/misc/Loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseAdMob.instance.initialize(appId: appID);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    asyncInit();
    super.initState();
  }

  asyncInit() async {
    //Set up persistent data
    mainPath = (await getApplicationDocumentsDirectory()).path;
    //Make it so I can control my own cache of files
    await getTemporaryDirectory().then((file) {
      Directory myDct = Directory(file.path + '/myStuff');
      if (!myDct.existsSync()) myDct.createSync();
      tmpPath = myDct.path;
    });
    //Persistent data
    dynamic data = PersistentData().getData();
    if (data != null) {
      sfwMatters = data['sfwMatters'] ?? true;
      autoPlayVids = data['autoPlay'] ?? true;
      hideCompletedDays = data['hideDays'] ?? true;
      warnCellular = data['warnCell'] ?? true;
      showNSFW = data['showNSFW'] ?? false;
      flaggedPosts = data['flaggedPosts'] ?? [];
      flaggedUsers = data['flaggedUsers'] ?? [];
      completedDays = data['completedDays'] ?? [];
      //These are the missing days
      //2/19 22
      //3/3 5 6 7 8 9 15
      //4/11 16 17 18 21 22 25 28
      //5/2 3 7
      //6/24
      //9/17
      //10/6 16 19 21 22 23 24 25 26 28 29
      //11/3 6 7 9 12 13 14 15 18 19 20 22 23 28
      savedPosts = data['SavedPosts'] ?? [];
      namedPosts = data['NamedPosts'] ?? {};
      myID = data['myID'];
    }
    //ID and Sign In
    FirebaseAuth auth = FirebaseAuth.instance;
    User user = auth.currentUser;
    if (myID == null && user == null) {
      createAccount('');
    } else {
      if (user == null) {
        await auth
            .signInWithEmailAndPassword(
                email: 'yourEmail', password: 'yourPassword')
            .catchError((e) {
          if ('$e'.contains('user-not-found')) createAccount('');
        }).then((us) => myID = user.email.split('@').first);
      } else {
        myID = user.email.split('@').first;
        PersistentData().writeData({'myID': myID});
      }
    }
    //Tags and Auth people who have paid
    await FirebaseFirestore.instance
        .collection('0000')
        .doc('0000-')
        .get()
        .then((value) {
      setState(() {
        tags = value.data()['tags'] ?? [];
        admin = value.data()['auth'].contains(myID) ?? false;
        showAds = !(value.data()['adless'].contains(myID) ?? false);
      });
    });
  }

  Future createAccount(String start) async {
    start += 'abcdefghijklmnopqrstuvwxyz0123456789'[Random().nextInt(36)];
    FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: '$start@archive.io',
      password: 'aVerySecurePassword',
    )
        .catchError((e) {
      if ('$e'.contains('email-already-in-use')) createAccount(start);
    }).whenComplete(() {
      myID = start;
      PersistentData().writeData({'myID': myID});
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    return FutureBuilder<Object>(
        future: Firebase.initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError)
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                primarySwatch: Colors.blue,
                brightness: Brightness.dark,
                visualDensity: VisualDensity.adaptivePlatformDensity,
              ),
              home: HomePage(),
            );
          return Loading(200);
        });
  }
}
