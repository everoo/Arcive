import 'package:arcive/misc/Interact.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../Globals.dart';

class CommentList extends StatelessWidget {
  final DocumentSnapshot doc;
  final ScrollController cont;

  CommentList(this.doc, {this.cont});

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, dynamic>> comments = doc
        .data()
        .entries
        .where((entry) => entry.key.length > 25 && !entry.key.startsWith('answer'))
        .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return ListView.builder(
      controller: cont,
      itemCount: comments.length + 2,
      itemBuilder: (c, i) {
        if (i == 0)
          return Column(
              children: [Container(height: screenSize.height * 0.55 + 48)]);
        if (i == comments.length + 1) return Container(height: 65);
        i--;
        List<Widget> childs = [];
        for (Widget child in likeButtons(comments[i].value[1], doc.reference,
            comment: comments[i])) {
          bool delete = child.key == Key('false');
          bool mine = comments[i].key.split('-').last == myID;
          childs.add(Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              (((mine || admin) && delete) || !delete)
                  ? Container(
                      width: 50,
                      child: RaisedButton(
                        shape: rRect,
                        color: Color(0),
                        elevation: 0,
                        child: Icon((delete)
                            ? Icons.delete_forever_rounded
                            : Icons.reply_rounded),
                        onPressed: () => (delete)
                            ? deleteComment(comments[i])
                            : comment(context, doc.reference,
                                sText: comments[i].key),
                      ),
                    )
                  : Container(),
              Container(child: child, width: 50),
            ],
          ));
        }
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: screenSize.width / 3,
              color: Theme.of(context).secondaryHeaderColor,
              child: Row(children: [
                childs[0],
                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Text(comments[i].key.substring(0, 19)),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                            color: Theme.of(context).bottomAppBarColor,
                          ),
                          child: MyText('${comments[i].value[0]}'),
                        ),
                      )
                    ],
                  ),
                ),
                childs[1]
              ]),
            ),
          ),
        );
      },
    );
  }

  deleteComment(MapEntry<String, dynamic> comment) async {
    lightImpact();
    await doc.reference.set(
      {comment.key: FieldValue.delete()},
      SetOptions(merge: true),
    );
  }
}
