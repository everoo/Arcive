import 'package:arcive/Globals.dart';
import 'package:arcive/misc/Loading.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccountPage extends StatefulWidget {
  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  GlobalKey<ScaffoldState> _scaffoldState = new GlobalKey();
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: accountStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          return DefaultTabController(
            length: 3,
            initialIndex: 1,
            child: Scaffold(
              key: _scaffoldState,
              appBar: AppBar(
                actions: [
                  IconButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          child: Dialog(
                            shape: rRect,
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      'Welcome to your account.\n\n'
                                      'The center page shows posts you have uploaded or saved.\n'
                                      'Click on them to go to said post and hold down on it to rename it.\n\n'
                                      '**If you want to save, report or share a post hold down on it in the main screen**\n'
                                      '\nSearch for posts with the filter text box.\n\n'
                                      'The page on the left has replies to your comments.\n\n'
                                      'The page on the right are settings and people you have blocked.\n',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 16)),
                                  MyText(
                                      'https://thespotsupport.blogspot.com/2021/01/archive-privacy-policy.html'),
                                  Text(
                                      '\nContact: evercole6@gmail.com for help')
                                ],
                              ),
                            ),
                          ));
                    },
                    icon: Icon(Icons.info_outline_rounded),
                  )
                ],
                bottom: TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.comment_rounded)),
                    Tab(icon: Icon(Icons.perm_media_rounded)),
                    Tab(icon: Icon(Icons.settings_rounded)),
                  ],
                ),
                title: Text((myID ?? '').toUpperCase()),
              ),
              body: TabBarView(
                children: [
                  replies(snapshot.data),
                  myMemes(snapshot.data.data()),
                  ListView(children: [
                    Container(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: [
                        switcher('Show NSFW posts', 'showNSFW', showNSFW,
                            (b) => showNSFW = b),
                        switcher('Blur NSFW posts', 'sfwMatters', sfwMatters,
                            (b) => sfwMatters = b),
                        switcher('Warn of cellular use', 'warnCell',
                            warnCellular, (b) => warnCellular = b),
                        switcher('Auto Play Videos', 'autoPlay', autoPlayVids,
                            (b) => autoPlayVids = b),
                        switcher(
                            'Hide Finished Days When Searching',
                            'hideDays',
                            hideCompletedDays,
                            (b) => hideCompletedDays = b),
                      ],
                    ),
                    load(),
                    (flaggedUsers.isEmpty && flaggedPosts.isEmpty)
                        ? Container()
                        : blocked(),
                  ]),
                ],
              ),
            ),
          );
        }
        return Loading(screenSize.width);
      },
    );
  }

  Widget switcher(String text, String data, bool value, Function(bool b) fn) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text(text),
        Switch(
          value: value,
          onChanged: (b) {
            setState(() => fn(b));
            readChild = null;
            PersistentData().writeData({data: b});
          },
        ),
      ],
    );
  }

  load() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: RaisedButton(
            shape: rRect,
            child: Text('Show Loading'),
            onPressed: () {
              lightImpact();
              showDialog(context: context, child: Loading(screenSize.width));
            }),
      );

  blocked() => Column(
        children: [
          Text('Blocked\n(Tap to Unblock)', textAlign: TextAlign.center),
          Row(
            children: [
              for (bool i in [true, false])
                (((i) ? flaggedUsers : flaggedPosts).isEmpty)
                    ? Container()
                    : Expanded(
                        child: Container(
                          height: screenSize.height,
                          child: ListView(
                            children: [
                              Center(child: Text((i) ? 'Users:' : 'Posts:')),
                              for (String blocked
                                  in (i) ? flaggedUsers : flaggedPosts)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  child: RaisedButton(
                                    shape: rRect,
                                    child: Text(blocked),
                                    onPressed: () => setState(
                                      () {
                                        readChild = null;
                                        if (i)
                                          flaggedUsers.remove(blocked);
                                        else
                                          flaggedPosts.remove(blocked);
                                        PersistentData().writeData(((i)
                                            ? {'flaggedUsers': flaggedUsers}
                                            : {'flaggedPosts': flaggedPosts}));
                                      },
                                    ),
                                  ),
                                )
                            ],
                          ),
                        ),
                      ),
            ],
          ),
        ],
      );

  Widget myMemes(Map<String, dynamic> data) {
    List<Widget> children = [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          decoration: decal(hintText: 'Filter'),
          textAlign: TextAlign.center,
          onChanged: (t) => setState(() => _filter = t),
        ),
      )
    ];
    for (bool s in [false, true]) {
      children += [
        Padding(
          padding: EdgeInsets.only(top: 12, bottom: 4),
          child: Text(s ? 'Saved Posts' : 'My Posts',
              style: TextStyle(fontSize: 18)),
        ),
        postWrap(
          s,
          ((s)
              ? (savedPosts ?? []).sublist(0)
              : [
                    for (DocumentReference post
                        in (data ?? {'posts': []})['posts'])
                      post.path
                  ] ??
                  [])
            ..retainWhere((_s) =>
                _filter.trim().isEmpty ||
                (namedPosts[_s] ?? '').contains(_filter) ||
                _s.contains(_filter)),
        )
      ];
    }
    return Column(children: children);
  }

  Widget postWrap(bool s, List posts) => Expanded(
        child: SingleChildScrollView(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (String post in posts.reversed)
                Padding(
                  padding: EdgeInsets.all(4),
                  child: Column(
                    children: [
                      Container(
                        height: 60,
                        width: 60,
                        child: RaisedButton(
                          padding: EdgeInsets.zero,
                          shape: CircleBorder(side: BorderSide.none),
                          color: Theme.of(context).indicatorColor,
                          onPressed: () => goTo(post),
                          onLongPress: () => renamePost(post, s),
                          child: Icon(
                            icons[post.split('-')[3]],
                            color: Theme.of(context).primaryColorDark,
                          ),
                        ),
                      ),
                      Container(
                        height: screenSize.height * 0.05,
                        width: screenSize.width / 4 - 16,
                        child: Text(
                            (namedPosts[post] == null || namedPosts[post] == '')
                                ? post
                                    .split('-')
                                    .sublist(0, 3)
                                    .join('-')
                                    .replaceFirst('/', '\n')
                                : namedPosts[post],
                            textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                )
            ],
          ),
        ),
      );

  goTo(String post) {
    lightImpact();
    getStream(post);
    Navigator.of(context).pop();
  }

  replies(DocumentSnapshot data) => ListView(children: [
        for (MapEntry<String, dynamic> t
            in (data.data() ?? {}).entries.where((e) => e.key != 'posts'))
          GestureDetector(
            onLongPress: () => goTo(t.value[0].path),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).secondaryHeaderColor,
                  ),
                  height: 150,
                  width: screenSize.width * 0.95,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          lightImpact();
                          await comment(context, t.value[0], sText: t.key);
                          await data.reference.set(
                            {t.key: FieldValue.delete()},
                            SetOptions(merge: true),
                          );
                        },
                        icon: Icon(Icons.reply_rounded),
                      ),
                      Expanded(
                          child: Column(children: [
                        Text(t.key.substring(0, 19)),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20)),
                              color: Theme.of(context).bottomAppBarColor,
                            ),
                            child: SingleChildScrollView(
                              child: MyText(
                                t.value[1],
                                docAction: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                        ),
                      ])),
                      IconButton(
                        onPressed: () async {
                          lightImpact();
                          await data.reference.set({t.key: FieldValue.delete()},
                              SetOptions(merge: true));
                        },
                        icon: Icon(Icons.delete_forever_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
      ]);

  renamePost(String post, bool s) {
    TextEditingController _cc = TextEditingController();
    showDialog(
      context: context,
      child: Dialog(
        shape: rRect,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Rename for searchability',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headline6,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                textAlign: TextAlign.center,
                autofocus: true,
                controller: _cc,
                decoration: decal(),
                onSubmitted: (s) {
                  PersistentData()
                      .writeData({'NamedPosts': namedPosts..[post] = s});
                  setState(() {});
                  Navigator.of(context).pop();
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (bool d in [false, true])
                  (!s && d)
                      ? Container()
                      : RaisedButton(
                          shape: rRect,
                          child: Text((d) ? 'Delete' : 'Rename'),
                          onPressed: () {
                            lightImpact();
                            if (d) {
                              namedPosts.remove(post);
                              savedPosts.remove(post);
                            } else
                              namedPosts[post] = _cc.text;
                            PersistentData().writeData({
                              'NamedPosts': namedPosts,
                              'SavedPosts': savedPosts
                            });
                            setState(() {});
                            Navigator.of(context).pop();
                          },
                        ),
                RaisedButton(
                    shape: rRect,
                    onPressed: () async {
                      lightImpact();
                      Navigator.of(context).pop();
                      await Clipboard.setData(new ClipboardData(text: post));
                      Scaffold.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Copied $post.\n(Can be put in search bar)')));
                    },
                    child: Text('Copy'))
              ],
            )
          ],
        ),
      ),
    );
  }
}
