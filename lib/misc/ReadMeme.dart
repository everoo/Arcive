import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:arcive/Globals.dart';
import 'package:arcive/misc/CommentList.dart';
import 'package:arcive/misc/Interact.dart';
import 'package:arcive/misc/VideoHolder.dart';
import 'package:arcive/misc/Loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'PictureHolder.dart';

class ReadMeme extends StatefulWidget {
  final List<DocumentSnapshot> datas;

  ReadMeme(this.datas);
  @override
  _ReadMemeState createState() => _ReadMemeState();
}

class _ReadMemeState extends State<ReadMeme>
    with SingleTickerProviderStateMixin {
  AnimationController _memeAngle;
  ScrollController _scroller = ScrollController();
  bool zoomed = false, hiding;
  Offset translate = Offset(0, 0);
  List<String> retrievingFiles = [];
  WebViewController _cont;
  String currentUrl = '';
  dynamic sharing;

  @override
  void initState() {
    hiding = !(widget.datas[docNum].data()['tags'] ?? []).contains('SFW') &&
        sfwMatters;
    _scroller.addListener(() => setState(() {
          translate = Offset(0, min(_scroller.offset, screenSize.height) / -2);
          zoomed = false;
        }));
    _memeAngle = AnimationController(
        vsync: this, value: 0, lowerBound: -3.14, upperBound: 3.14)
      ..addListener(() => setState(() {}));
    super.initState();
  }

  asyncBuild() {
    //Meme
    String id = widget.datas[docNum].id;
    String type = id.split('-')[1];
    if (type == 'stories') {
      story(widget.datas[docNum].data()['story']);
    } else if (type == 'polls') {
      readChild = poll();
    } else {
      getFile(id, type, true);
    }
    //Load next and prev meme
    for (int i in [-1, 1]) {
      if (docNum + i < widget.datas.length && docNum + i >= 0) {
        String id1 = widget.datas[docNum + i].id;
        String type1 = id1.split('-')[1];
        if (['videos', 'images'].contains(type1)) getFile(id1, type1, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (readChild == null) asyncBuild();
    return Transform.rotate(
      angle: _memeAngle.value,
      alignment: Alignment(0, -0.9),
      child: Stack(
        children: [
          GestureDetector(
            onHorizontalDragStart: (d) => menu.animateTo(1),
            onHorizontalDragUpdate: (d) => setState(
                () => _memeAngle.value -= d.primaryDelta / screenSize.width),
            onHorizontalDragEnd: (d) async {
              if (d.primaryVelocity != 0) {
                int way = -d.primaryVelocity.sign.toInt();
                int tmpNum = max(min(docNum + way, widget.datas.length - 1), 0);
                if (tmpNum == docNum) {
                  lightImpact();
                  DateTime _now = DateTime.now().toUtc();
                  String t = '$currentDay'.substring(0, 10);
                  if (way > 0 &&
                      !(currentDay.day == _now.day &&
                          currentDay.month == _now.month &&
                          currentDay.year == _now.year) &&
                      !completedDays.contains(t))
                    PersistentData()
                        .writeData({'completedDays': completedDays..add(t)});
                } else {
                  docNum = tmpNum;
                  hiding = !(widget.datas[docNum].data()['tags'] ?? [])
                          .contains('SFW') &&
                      sfwMatters;
                  _scroller.jumpTo(0);
                  await _memeAngle.animateTo(3.14 * way,
                      duration: Duration(milliseconds: 100));
                  readChild = null;
                  _memeAngle.value = -3.14 * way;
                }
              }
              _memeAngle.animateTo(0,
                  duration: Duration(milliseconds: 800),
                  curve: Curves.elasticOut);
            },
            child: CommentList(widget.datas[docNum], cont: _scroller),
          ),
          interactButtons(),
          meme(),
          zoomIcon()
        ],
      ),
    );
  }

  story(String text) {
    String trimmed = text.trim();
    sharing = text;
    if (trimmed.startsWith(validURL) && !hiding) {
      if (currentUrl == trimmed || _cont == null) {
        readChild = WebView(
          initialUrl: trimmed,
          onWebViewCreated: (c) => _cont = c,
          javascriptMode: JavascriptMode.unrestricted,
        );
      } else {
        _cont.loadUrl(trimmed);
      }
      currentUrl = trimmed;
    } else {
      readChild = Container(
        child: MyText(text),
        color: Color(0),
      );
    }
  }

  Widget poll() {
    Map<String, dynamic> data = widget.datas[docNum].data();
    bool voted = false;
    double myWidth = (screenSize.width - 32);
    String sharingText = data['question'] + '\n';
    Map<String, int> answers = {};
    data.forEach((k, v) {
      if (k.startsWith('answer:')) {
        String option = k.substring(7);
        int len = v.length;
        answers[option] = len;
        sharingText += '$option : $len\n';
        if (v.contains(myID)) voted = true;
      }
    });
    sharing = sharingText;
    int total = answers.values.reduce((v, e) => v += e);
    return Column(
      key: Key(widget.datas[docNum].id),
      children: [
        Container(
          height: screenSize.height * 0.05,
          child: SingleChildScrollView(
            child: MyText('\n${data['question']}\n'),
          ),
        ),
        Expanded(
          child: ListView(
              padding: EdgeInsets.only(bottom: 8),
              physics: (screenSize.height * 0.55 / answers.length < 100)
                  ? null
                  : NeverScrollableScrollPhysics(),
              children: [
                for (MapEntry answer in answers.entries)
                  Container(
                    padding: EdgeInsets.all(8),
                    height: max(100, screenSize.height * 0.5 / answers.length),
                    child: GestureDetector(
                      onTap: (voted)
                          ? null
                          : () async {
                              lightImpact();
                              await widget.datas[docNum].reference.set({
                                'answer:' + answer.key:
                                    FieldValue.arrayUnion([myID])
                              }, SetOptions(merge: true));
                              setState(() => readChild = null);
                            },
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                                color: Theme.of(context).bottomAppBarColor,
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          AnimatedContainer(
                            duration: Duration(milliseconds: 800),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: RadialGradient(
                                  center: Alignment(-1.5, -1.5),
                                  radius: 3,
                                  colors: [
                                    Theme.of(context).indicatorColor,
                                    Theme.of(context).buttonColor
                                  ],
                                )),
                            width: (voted)
                                ? answer.value / total * myWidth
                                : myWidth,
                          ),
                          Row(
                            children: [
                              AnimatedContainer(
                                duration: Duration(milliseconds: 800),
                                child: MyText(answer.key),
                                width: (voted) ? myWidth / 2 : myWidth,
                              ),
                              AnimatedContainer(
                                duration: Duration(milliseconds: 800),
                                child: (voted)
                                    ? SingleChildScrollView(
                                        child: MyText(answer.value.toString()))
                                    : null,
                                width: (voted) ? myWidth / 2 : 0,
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
              ]),
        ),
      ],
    );
  }

  getFile(String id, String type, bool setting) async {
    String date = widget.datas.first.reference.path.split('/').first;
    File file =
        File('$tmpPath/$date--$id.' + ((type == 'videos') ? 'mp4' : 'png'));
    if (setting) sharing = file;
    if (file.existsSync()) {
      if (setting) futureChild(file, type);
    } else if (!retrievingFiles.contains(id)) {
      retrievingFiles.add(id);
      await FirebaseStorage.instance
          .ref()
          .child(date.substring(0, 4))
          .child(date.substring(5, 7))
          .child(date.substring(0, 10))
          .child(id)
          .getData()
          .then((bytes) async {
        await file.writeAsBytes(bytes).catchError((e) => print(e));
        if (setting) futureChild(file, type);
        retrievingFiles.remove(id);
      });
    }
  }

  futureChild(File file, String type) =>
      setState(() => readChild = (type == 'videos')
          ? MyVideoPlayer(Key(file.path), file, !hiding)
          : MyPictureHolder(Image.file(file)));

  Widget meme() {
    Widget child = readChild ?? Loading(screenSize.width - 16);
    if (hiding) {
      child = Stack(
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Center(child: child),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              lightImpact();
              switch (widget.datas[docNum].id.split('-')[1]) {
                case 'stories':
                  if (widget.datas[docNum].data()['story'].startsWith(validURL))
                    readChild = null;
                  break;
                case 'videos':
                  readChild = null;
                  break;
              }
              hiding = false;
            }),
            // onLongPress: () => interactPost(widget.datas[docNum]),
            child: Container(
              color: Color(0),
              height: screenSize.height * 0.55,
              width: screenSize.width - 32,
              child: Center(
                child: Text(
                  'Not tagged SFW\nTap to remove blur',
                  style: TextStyle(shadows: [Shadow(blurRadius: 8)]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      child = GestureDetector(
        child: child,
        onLongPress: () => sharePost(),
      );
    }
    return Transform.translate(
      offset: (zoomed) ? Offset.zero : translate,
      child: Container(
        decoration: BoxDecoration(boxShadow: [
          BoxShadow(
            blurRadius: 6,
            offset: Offset(4, 4),
            color: Color(0x22000000),
          )
        ], borderRadius: BorderRadius.circular(25)),
        margin: EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Container(
            color: Theme.of(context).secondaryHeaderColor,
            height: screenSize.height * 0.55,
            width: screenSize.width - 16,
            child: child,
          ),
        ),
      ),
    );
  }

  sharePost() => interactPost(widget.datas[docNum], context, sharing)
      .then((_) => setState(() {}));

  Widget zoomIcon() => (zoomed || translate.dy == 0)
      ? Container()
      : Positioned(
          right: 8,
          top: screenSize.height * 0.55,
          child: Opacity(
            opacity: min(max(0, translate.dy / screenSize.height * -2), 1),
            child: IconButton(
              icon: Icon(Icons.arrow_circle_down_outlined),
              onPressed: () {
                _scroller.jumpTo(_scroller.offset);
                setState(() => zoomed = true);
              },
            ),
          ),
        );

  interactButtons() => Transform.translate(
        offset: Offset(0, screenSize.height * 0.55 + 8) +
            ((zoomed) ? Offset.zero : translate * 1.5),
        child: Container(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: likeButtons(widget.datas[docNum].data()['likes'] ?? {},
                widget.datas[docNum].reference)
              ..insert(
                  1,
                  RaisedButton(
                    shape: rRect,
                    color: Color(0),
                    elevation: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.comment_rounded),
                      ],
                    ),
                    onPressed: () =>
                        comment(context, widget.datas[docNum].reference),
                  )),
          ),
        ),
      );
}
