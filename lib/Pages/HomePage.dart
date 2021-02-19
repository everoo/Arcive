import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:arcive/Pages/AccountPage.dart';
import 'package:arcive/Pages/CreatePage.dart';
import 'package:arcive/Globals.dart';
import 'package:arcive/misc/ReadMeme.dart';
import 'package:arcive/misc/Filter.dart';
import 'package:arcive/misc/Loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<List> children;
  List<String> filterTags = [], filterTypes = [];
  List<int> filterNums = List.generate(6, (_) => null);
  StreamSubscription _intentDataStreamSubscription;
  StreamSubscription _sub;

  @override
  void initState() {
    //Set up the FAB
    menu = AnimationController(
        vsync: this, duration: Duration(milliseconds: 200), value: 1)
      ..addListener(() => setState(() {}));
    children = List.generate(
      5,
      (i) => [
        (i > 1) ? Offset(65.0 * (i - 1), 0) : Offset(0, 65.0 * (i + 1)),
        FloatingActionButton(
          heroTag: i,
          backgroundColor: Color(0xff229920 + Random().nextInt(220)),
          child: Icon([
            Icons.add,
            Icons.account_circle_rounded,
            Icons.search_rounded,
            Icons.filter_list_rounded,
            Icons.flag_rounded,
          ][i]),
          tooltip: ['Add Post', 'Account', 'Search', 'Filter', 'Flagged'][i],
          onPressed: () => action(i),
        )
      ],
    )..last[0] = Offset(65, 65);
    //Listen for data shared to app
    _intentDataStreamSubscription = ReceiveSharingIntent.getMediaStream()
        .listen((List<SharedMediaFile> value) =>
            filterType((value ?? [null]).first));
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) =>
        setState(() => filterType((value ?? [null]).first)));
    _intentDataStreamSubscription = ReceiveSharingIntent.getTextStream()
        .listen((String t) => goCreateString(t));
    ReceiveSharingIntent.getInitialText().then((String t) => goCreateString(t));
    super.initState();
    //Listen to wifi events
    Connectivity().checkConnectivity().then((r) => showConnectionState(r));
    _sub = Connectivity()
        .onConnectivityChanged
        .listen((r) => showConnectionState(r));
    displayBanner();
  }

  bool showingWarning = false;
  showConnectionState(ConnectivityResult res) async {
    if (res == ConnectivityResult.mobile && warnCellular && !showingWarning) {
      showingWarning = true;
      await showDialog(
        context: context,
        child: Dialog(
          shape: rRect,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
                'Just a heads up you\'re using cellular data.\n'
                '(you can turn this warning off in account settings)',
                textAlign: TextAlign.center),
          ),
        ),
      );
      showingWarning = false;
    } else if (res == ConnectivityResult.wifi && showingWarning) {
      Navigator.of(context).pop();
    }
  }

  goCreateString(String value) async {
    if (value != null) {
      List<String> values = value.split('\n');
      List<String> answers = [];
      int n;
      for (String val in values.sublist(1)) {
        List<String> t = val.split(' : ');
        n = int.tryParse(t.removeLast());
        if (n == null) break;
        answers.add(t.join(' : '));
      }
      if (n == null) {
        await switchPages(CreatePage(text: value));
      } else {
        await switchPages(CreatePage(poll: [values.first] + answers));
      }
      displayBanner();
    }
  }

  filterType(SharedMediaFile file) async {
    if (file != null) {
      if (file.type == SharedMediaType.IMAGE) {
        await switchPages(CreatePage(image: File(file.path)));
      } else if (file.type == SharedMediaType.VIDEO) {
        await switchPages(CreatePage(video: File(file.path)));
      }
      displayBanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    checkSize(context);
    Directory(tmpPath).listSync().forEach((file) {
      DateTime dd = DateTime.tryParse(file.path
          .substring(tmpPath.length + 1, tmpPath.length + 20)
          .replaceAll('--', ' '));
      if (dd != null) if (file.statSync().type == FileSystemEntityType.file &&
          dd.difference(DateTime.now().toUtc()).inDays != 0 &&
          dd.difference(currentDay).inDays != 0) {
        file.deleteSync();
      }
    });
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.data == null ||
            snapshot.connectionState != ConnectionState.active)
          return Loading(screenSize.width);
        List<QueryDocumentSnapshot> snaps = snapshot.data.docs;
        snaps.removeWhere((snap) =>
            (flaggedUsers ?? []).contains(snap.id.split('-').last) ||
            (flaggedPosts ?? []).contains(snap.id));
        if (!showNSFW)
          snaps.retainWhere(
              (snap) => (snap.data()['tags'] ?? []).contains('SFW'));
        if (filterTags.isNotEmpty)
          snaps.retainWhere((snap) =>
              (snap.data()['tags'] ?? []).any((t) => filterTags.contains(t)));
        if ([1, 2, 3].contains(filterTypes.length))
          snaps.retainWhere(
              (snap) => filterTypes.contains(snap.id.split('-')[1]));
        if (filterNums.any((n) => n != null))
          snaps.retainWhere((snap) {
            Map likes = snap.data()['likes'] ?? {};
            int likeCount = likes.values.where((b) => b).length;
            int l = 0;
            for (int n in [
              likeCount,
              likes.length - likeCount,
              snap.data().keys.where((k) => k.length > 24).length,
            ]) {
              if (filterNums[l] != null && filterNums[l + 1] != null) {
                return (n > filterNums[l] && n < filterNums[l + 1]);
              } else {
                if (filterNums[l] != null) if (n > filterNums[l]) return true;
                l++;
                if (filterNums[l] != null) if (n < filterNums[l]) return true;
                l++;
              }
            }
            return false;
          });
        if (wantedDoc != null) {
          docNum = snaps.indexWhere((element) => element.id == wantedDoc);
          wantedDoc = null;
          readChild = null;
        }
        if (docNum >= snaps.length) docNum = snaps.length - 1;
        if (docNum < 0) docNum = 0;
        return Scaffold(
          appBar: PreferredSize(
              preferredSize: Size.fromHeight((showingAd)
                  ? 60.0 - ((Platform.isIOS) ? 0 : screenPadding.top)
                  : 0.0),
              child: AppBar()),
          body: (snaps.length == 0)
              ? MyText('NOTHING TO SEE HERE\nMOVE ALONG\nDO NOT ADD ANYTHING')
              : ReadMeme(snaps),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: Stack(
            children: [
              for (List child in children)
                ((menu.value == 1) || (children.last == child && !admin))
                    ? Container()
                    : Positioned(
                        right: (1 - menu.value) * child[0].dx,
                        bottom: (1 - menu.value) * child[0].dy,
                        child: child[1]),
              Positioned(
                right: 0,
                bottom: 0,
                child: FloatingActionButton(
                  heroTag: -1,
                  tooltip: (menu.value > 0.5) ? 'Open Menu' : 'Close Menu',
                  child: AnimatedIcon(
                      icon: AnimatedIcons.close_menu, progress: menu),
                  backgroundColor: Color.lerp(Color(0xFFCC2233),
                      Theme.of(context).indicatorColor, menu.value),
                  onPressed: () {
                    lightImpact();
                    (menu.value > 0.5) ? menu.reverse() : menu.forward();
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  dispose() {
    menu.dispose();
    _intentDataStreamSubscription.cancel();
    _sub.cancel();
    hideBanner();
    super.dispose();
  }

  Future switchPages(Widget child) async {
    hideBanner();
    return Navigator.push(
        context, MaterialPageRoute(builder: (context) => child));
  }

  bool disposed = true, showingAd = false;
  BannerAd _bannerAd;

  BannerAd _createBanner() {
    return BannerAd(
        adUnitId: (kReleaseMode) ? unitId : BannerAd.testAdUnitId,
        size: AdSize.fullBanner,
        listener: (MobileAdEvent event) {
          if (event == MobileAdEvent.loaded) if (disposed)
            _bannerAd.dispose();
          else
            _bannerAd
                .show(anchorType: AnchorType.top)
                .then((_) => setState(() => showingAd = true));
        });
  }

  void displayBanner() async {
    if (showAds) {
      disposed = false;
      if (_bannerAd == null) _bannerAd = _createBanner();
      _bannerAd.load();
    }
  }

  void hideBanner() async {
    await _bannerAd?.dispose();
    disposed = true;
    _bannerAd = null;
    showingAd = false;
  }

  action(int i) async {
    lightImpact();
    menu.forward();
    switch (i) {
      case 0:
      case 1:
        bool wasPlaying = vidCont?.value?.isPlaying ?? false;
        vidCont?.pause();
        await switchPages((i == 0) ? CreatePage() : AccountPage());
        if (wasPlaying) vidCont?.play();
        displayBanner();
        break;
      case 2:
        /////////Search
        String doc;
        DateTime now = DateTime.now().toUtc(),
            day,
            startDay = DateTime(2020, 02, 10),
            initialDate = (currentDay.isBefore(startDay))
                ? startDay
                : (currentDay.isAfter(now))
                    ? now
                    : currentDay;
        if (await showDialog(
          context: context,
          child: Dialog(
            shape: rRect,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CalendarDatePicker(
                    firstDate: startDay,
                    initialDate: initialDate,
                    lastDate: now,
                    onDateChanged: (DateTime value) => day = value,
                    selectableDayPredicate: (hideCompletedDays)
                        ? (d) {
                            String s = '$d'.substring(0, 10);
                            return !completedDays.contains(s) ||
                                s == '$initialDate'.substring(0, 10);
                          }
                        : null,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      onChanged: (t) => doc = t,
                      keyboardType: TextInputType.number,
                      decoration: decal(hintText: 'Post Number'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  RaisedButton(
                    shape: rRect,
                    onPressed: () {
                      lightImpact();
                      Navigator.of(context).pop(true);
                    },
                    child: Text('Search'),
                  )
                ],
              ),
            ),
          ),
        ))
          setState(() {
            if (day != null) {
              currentDay = day;
              stream = FirebaseFirestore.instance
                  .collection('$day'.substring(0, 10))
                  .snapshots();
            }
            if (doc == null)
              docNum = 0;
            else {
              if (doc.startsWith(validDoc)) {
                getStream(doc);
                setState(() {});
              } else {
                docNum = (int.tryParse(doc) ?? 1) - 1;
              }
            }
            readChild = null;
          });
        break;
      case 3:
        ///////Filter
        Filter filter = Filter(filterTags.sublist(0), filterTypes.sublist(0),
            filterNums.sublist(0));
        if (await showDialog(context: context, child: filter) ?? false) {
          setState(() {
            filterTags = filter.selectedTags;
            filterTypes = filter.selectedTypes;
            filterNums = filter.nums;
            readChild = null;
          });
        }
        break;
      case 4:
        /////Show Flagged
        flagged = !flagged;
        if (flagged) docNum = 0;
        readChild = null;
        children.last[1] = FloatingActionButton(
          heroTag: i,
          backgroundColor: Color(0xff229920 + Random().nextInt(220)),
          child:
              Icon((flagged) ? Icons.exit_to_app_rounded : Icons.flag_rounded),
          tooltip: 'Flagged',
          onPressed: () => action(4),
        );
        setState(() {
          if (flagged) {
            stream = FirebaseFirestore.instance
                .collection('0000flagged')
                .snapshots();
          } else {
            stream = FirebaseFirestore.instance
                .collection('$currentDay'.substring(0, 10))
                .snapshots();
          }
        });
        break;
    }
  }
}
