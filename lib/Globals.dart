import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

Size screenSize;
EdgeInsets screenPadding;
String myID, wantedDoc, tmpPath, mainPath;
int docNum = 0;
bool admin = false,
    sfwMatters = true,
    flagged = false,
    autoPlayVids = true,
    hideCompletedDays = true,
    showNSFW = false,
    warnCellular = true,
    showAds = true;
List tags, flaggedUsers, flaggedPosts, savedPosts, completedDays = [];
Map namedPosts = {};
Widget readChild;
VideoPlayerController vidCont, createCont;
RegExp validURL = RegExp(
        r'(f|ht)tps?:\/\/([\w_-]+(?:(?:\.[\w_-]+)+))([\w.,@?^=%&:\/~+#-]*[\w@?^=%&\/~+#-])?'),
    validDoc = RegExp(
        '[0-9]{4}-[0-1]{1}[0-9]{1}-[0-3]{1}[0-9]{1}\/([0-9]{2}:){2}[0-9]{2}-[a-z]*-[a-z0-9]*');
AnimationController menu;
DateTime currentDay = DateTime.now().toUtc();

enum CreationType { image, video, poll, story }

Map<CreationType, String> types = {
  CreationType.image: 'images',
  CreationType.poll: 'polls',
  CreationType.story: 'stories',
  CreationType.video: 'videos'
};

Map<String, IconData> icons = {
  'images': Icons.image,
  'polls': Icons.poll,
  'stories': Icons.import_contacts,
  'videos': Icons.play_circle_filled
};

Future<void> lightImpact() async =>
    await SystemChannels.platform.invokeMethod<void>(
      'HapticFeedback.vibrate',
      'HapticFeedbackType.lightImpact',
    );

checkSize(BuildContext context) {
  if (screenSize == null || screenPadding == null) {
    MediaQueryData query = MediaQuery.of(context);
    screenSize = query.size;
    screenPadding = query.viewPadding;
  }
}

Stream stream = FirebaseFirestore.instance
    .collection('$currentDay'.substring(0, 10))
    .snapshots();
Stream<DocumentSnapshot> accountStream =
    FirebaseFirestore.instance.collection('0000').doc(myID).snapshots();

String unitId = 'ca-app-pub-2732851918745448/' +
    ((Platform.isIOS) ? '5606896116' : '4937291206');
String appID = 'ca-app-pub-2732851918745448~' +
    ((Platform.isIOS) ? '9909103202' : '7563454543');

extension CapExtension on String {
  String get capitalizeFirst => '${this[0].toUpperCase()}${this.substring(1)}';
}

InputDecoration decal({String hintText}) => InputDecoration(
      hintText: hintText,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      filled: true,
    );

ShapeBorder rRect =
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

getStream(String doc) {
  flagged = false;
  List<String> ids = doc.split('/');
  List<int> _now = [for (String p in ids.first.split('-')) int.tryParse(p)];
  currentDay = DateTime(_now[0], _now[1], _now[2]);
  wantedDoc = ids.last;
  stream = FirebaseFirestore.instance
      .collection('$currentDay'.substring(0, 10))
      .snapshots();
}

class MyText extends StatefulWidget {
  final String text;
  final Function docAction;
  const MyText(this.text, {this.docAction});

  @override
  _MyTextState createState() => _MyTextState();
}

class _MyTextState extends State<MyText> {
  TapGestureRecognizer getRecognizer(String url, bool doc) =>
      TapGestureRecognizer()
        ..onTap = () {
          lightImpact();
          if (doc) {
            getStream(url);
            if (widget.docAction != null) widget.docAction();
            menu.reset();
            menu.animateTo(1, duration: Duration(milliseconds: 0));
            return;
          }
          showDialog(
            context: context,
            builder: (c) => Dialog(
              shape: rRect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  height: screenSize.height * 0.55,
                  width: screenSize.width * 0.92,
                  child: WebView(
                    initialUrl: url,
                    javascriptMode: JavascriptMode.unrestricted,
                    onWebResourceError: (c) => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          );
        };

  @override
  Widget build(BuildContext context) {
    List<InlineSpan> children = [];
    widget.text
        .replaceAllMapped(validURL, (t) => '{' + t.group(0) + '|l}')
        .replaceAllMapped(validDoc, (t) => '{' + t.group(0) + '|d}')
        .split(RegExp('[{}]'))
        .forEach((tt) {
      List<String> texts = tt.split('|');
      TextStyle style = Theme.of(context).textTheme.bodyText1;
      GestureRecognizer recognizer;
      texts.sublist(1).forEach((t) {
        if (t == 'l') {
          recognizer = getRecognizer(texts[0], false);
          style = style.apply(
              color: Colors.blue, decoration: TextDecoration.underline);
        }
        if (t == 'd') {
          recognizer = getRecognizer(texts[0], true);
          style = style.apply(
              color: Colors.blue, decoration: TextDecoration.underline);
        }
        if (t == 'b') style = style.apply(fontWeightDelta: 4);
        if (t == 'i') style = style.apply(fontStyle: FontStyle.italic);
        if (t == 'o')
          style = style.apply(
              decoration: TextDecoration.combine(
                  [style.decoration, TextDecoration.overline]));
        if (t == 's')
          style = style.apply(
              decoration: TextDecoration.combine(
                  [style.decoration, TextDecoration.lineThrough]));
        if (t == 'u')
          style = style.apply(
              decoration: TextDecoration.combine(
                  [style.decoration, TextDecoration.underline]));
        if (t == 'wavy')
          style = style.apply(decorationStyle: TextDecorationStyle.wavy);
        if (t == 'dd')
          style = style.apply(decorationStyle: TextDecorationStyle.double);
        bool c = t.startsWith('0x');
        if (c || t.startsWith('1x')) {
          if (int.tryParse(t.substring(2), radix: 16) != null) {
            Color color = Color(int.parse(t.substring(2), radix: 16));
            style = style.apply(
                color: (c) ? color : null, backgroundColor: (c) ? null : color);
          }
        } else if (int.tryParse(t) != null) {
          style = style.apply(fontSizeDelta: int.parse(t).toDouble());
        }
      });
      children
          .add(TextSpan(text: texts[0], style: style, recognizer: recognizer));
    });
    return Center(
      child: SingleChildScrollView(
        physics: ClampingScrollPhysics(),
        child: Center(
          child: Container(
            alignment: Alignment.center,
            child: RichText(
              text: TextSpan(children: children),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

//COMMENT
Future comment(BuildContext c, DocumentReference doc, {String sText}) async {
  TextEditingController cont = TextEditingController(
      text: ((sText == null) ? '' : '@' + sText.substring(0, 19) + '\n'));
  cont.selection = TextSelection(
    baseOffset: cont.text.length,
    extentOffset: cont.text.length,
  );
  String text = await showDialog(
    context: c,
    builder: (c) => Dialog(
      shape: rRect,
      child: Container(
        margin: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Do or do not leave a comment, there is no try.',
                style: TextStyle(fontSize: 20), textAlign: TextAlign.center),
            Container(height: 4),
            TextField(
              enableInteractiveSelection: true,
              autofocus: true,
              decoration: decal(),
              maxLines: 6,
              controller: cont,
              textAlign: TextAlign.center,
            ),
            RaisedButton(
              shape: rRect,
              child: Text('Comment'),
              onPressed: () {
                lightImpact();
                Navigator.of(c).pop(cont.text);
              },
            )
          ],
        ),
      ),
    ),
  );
  if (text.trim().isNotEmpty) {
    WriteBatch _batch = FirebaseFirestore.instance.batch();
    String _title =
        DateTime.now().toUtc().toString().replaceFirst('Z', '-' + myID);
    _batch.set(
        doc,
        {
          _title: [
            text,
            {myID: true}
          ]
        },
        SetOptions(merge: true));
    if (sText != null) {
      _batch.set(
          FirebaseFirestore.instance
              .collection('0000')
              .doc(sText.split('-').last),
          {
            _title: [doc, text]
          },
          SetOptions(merge: true));
    }
    await _batch.commit();
  }
  return text.trim().isNotEmpty;
}

class PersistentData {
  File file() => File('$mainPath/preference.json');

  writeData(Map<String, dynamic> data) {
    if (file().existsSync()) {
      file().writeAsStringSync(
          json.encode(json.decode(file().readAsStringSync())..addAll(data)));
    } else {
      file().writeAsStringSync(json.encode(data));
    }
  }

  dynamic getData([String key]) {
    if (file().existsSync()) {
      Map foo = json.decode(file().readAsStringSync());
      if (key == null) return foo;
      return foo[key];
    } else
      return null;
  }
}
