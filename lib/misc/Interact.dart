import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';

import '../Globals.dart';

_share(dynamic sharing) {
  if (sharing != null) {
    if (sharing.runtimeType == String)
      Share.share(sharing);
    else
      Share.shareFiles([sharing.path]);
  }
}

_archive(BuildContext context, DocumentSnapshot doc) async {
  savedPosts.add(doc.reference.path);
  PersistentData().writeData({'SavedPosts': savedPosts});
  TextEditingController _cc = TextEditingController();
  String description = await showDialog(
    context: context,
    child: Dialog(
        shape: rRect,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You\'ve saved this post. Would you like to add a description for searchability?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextField(
                  controller: _cc,
                  autofocus: true,
                  decoration: decal(hintText: 'Your Description'),
                  textInputAction: TextInputAction.go,
                  onSubmitted: (s) => Navigator.of(context).pop(s),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (bool t in [false, true])
                    RaisedButton(
                        shape: rRect,
                        child: Text((t) ? 'Yes' : 'No'),
                        onPressed: () =>
                            Navigator.of(context).pop((t) ? _cc.text : null)),
                ],
              )
            ],
          ),
        )),
  );
  namedPosts[doc.reference.path] = description ?? '';
  PersistentData().writeData({'NamedPosts': namedPosts});
}

_action(String i, DocumentSnapshot doc, BuildContext context,
    dynamic sharing) async {
  switch (i) {
    case 'Share/Download':
      await _share(sharing);
      break;
    case 'Archive':
      await _archive(context, doc);
      break;
    case 'Copy':
      Clipboard.setData(new ClipboardData(text: doc.reference.path));
      Scaffold.of(context).showSnackBar(SnackBar(
          content: Text(
        'Copied: ${doc.reference.path}'
        '\n(This can be pasted into the search bar for quick access)',
        textAlign: TextAlign.center,
      )));
      break;
    case 'Unreport':
      await FirebaseFirestore.instance.doc(doc.reference.path).delete();
      readChild = null;
      break;
    case 'Tag SFW':
    case 'Tag NSFW':
      await FirebaseFirestore.instance.doc(doc.reference.path).set({
        'tags': ((doc.data()['tags'] ?? []).contains('SFW'))
            ? FieldValue.arrayRemove(['SFW'])
            : FieldValue.arrayUnion(['SFW'])
      }, SetOptions(merge: true));
      break;
    case 'Delete':
      List<String> ids =
          ((flagged) ? doc.data()['ref'] : doc.reference).path.split('/');
      if (doc.data()['url'] != null) {
        String date = ids.first;
        await FirebaseStorage.instance
            .ref()
            .child(date.substring(0, 4))
            .child(date.substring(5, 7))
            .child(date.substring(0, 10))
            .child(ids.last)
            .delete();
        File file = File('$tmpPath/myStuff/${ids.last}.' +
            ((doc.id.split('-')[1] == 'videos') ? 'mp4' : 'png'));
        if (file.existsSync()) file.deleteSync();
      }
      WriteBatch _write = FirebaseFirestore.instance.batch();
      if (flagged) _write.delete(doc.data()['ref']);
      _write.delete(doc.reference);
      _write.update(
          FirebaseFirestore.instance.collection('0000').doc(
              ((flagged) ? doc.data()['ref'] : doc.reference)
                  .path
                  .split('-')
                  .last),
          {
            'posts': FieldValue.arrayRemove(
                [(flagged) ? doc.data()['ref'] : doc.reference])
          });
      await _write.commit();
      readChild = null;
      break;
  }
}

Future interactPost(
    DocumentSnapshot doc, BuildContext context, dynamic sharing) async {
  lightImpact();
  Map<String, bool> texts = {
    'Share/Download': sharing != null,
    'Archive': !savedPosts.contains(doc.reference.path),
    'Unreport': flagged,
    'Tag ${(doc.data()['tags'] ?? []).contains('SFW') ? 'N' : ''}SFW': admin,
    'Copy': true,
    'Delete': doc.id.split('-').last == myID || admin
  };
  return showDialog(
      context: context,
      child: Dialog(
        shape: rRect,
        child: Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (String tt in texts.keys)
              (texts[tt])
                  ? RaisedButton(
                      onPressed: () async {
                        lightImpact();
                        await _action(tt, doc, context, sharing);
                        Navigator.of(context).pop();
                      },
                      shape: rRect,
                      child: Text(tt),
                    )
                  : Container(),
            for (String t in ['Post', 'User'])
              (flagged)
                  ? Container()
                  : RaisedButton(
                      shape: rRect,
                      onPressed: () async {
                        if (t == 'Post')
                          flaggedPosts.add(doc.id);
                        else
                          flaggedUsers.add(doc.id.split('-').last);
                        PersistentData().writeData({
                          'flaggedPosts': flaggedPosts,
                          'flaggedUsers': flaggedUsers
                        });
                        Navigator.of(context).pop();
                        readChild = null;
                        menu.reset();
                        menu.animateTo(1, duration: Duration(seconds: 0));
                        await FirebaseFirestore.instance
                            .collection('0000flagged')
                            .doc(doc.id)
                            .set(doc.data()..['ref'] = doc.reference);
                      },
                      child: Text('Report ' + t),
                    ),
          ],
        ),
      ));
}

like(bool way, DocumentReference ref,
    {MapEntry<String, dynamic> comment}) async {
  lightImpact();
  await FirebaseFirestore.instance.runTransaction((transaction) async {
    DocumentSnapshot newData = await transaction.get(ref);
    Map likes =
        (comment == null) ? newData['likes'] : newData.data()[comment.key][1];
    (likes[myID] == way) ? likes.remove(myID) : likes[myID] = way;
    if (comment == null) {
      transaction.update(ref, {'likes': likes});
    } else {
      transaction.set(
          ref,
          {
            comment.key: [comment.value[0], likes]
          },
          SetOptions(merge: true));
    }
  });
}

List<Widget> likeButtons(Map likes, DocumentReference docRef,
    {MapEntry<String, dynamic> comment}) {
  List<Widget> children = [];
  for (bool t in [true, false]) {
    List<Widget> childs = [
      Text('${likes.values.where((b) => b == t).length}'),
      Container(width: 4),
      Icon((t) ? Icons.thumb_up_rounded : Icons.thumb_down_rounded)
    ];
    children.add(
      RaisedButton(
        shape: rRect,
        key: Key(t.toString()),
        color: Color(0),
        elevation: (comment == null) ? 1 : 0,
        child: (comment == null)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: (t) ? childs.reversed.toList() : childs,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: childs,
              ),
        onPressed: () => like(t, docRef, comment: comment),
      ),
    );
  }
  return children;
}
