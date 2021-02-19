import 'dart:io';
import 'package:arcive/Globals.dart';
import 'package:arcive/misc/Loading.dart';
import 'package:arcive/misc/PictureHolder.dart';
import 'package:arcive/misc/VideoHolder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreatePage extends StatefulWidget {
  final File image, video;
  final CreationType type;
  final String text;
  final List<String> poll;

  const CreatePage(
      {Key key, this.image, this.video, this.type, this.text, this.poll})
      : super(key: key);
  @override
  _CreatePageState createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  TextEditingController commentCont = TextEditingController(),
      storyCont = TextEditingController();
  FocusNode commentFocus = FocusNode(), storyFocus = FocusNode();

  List<FocusNode> pollFocus = List.generate(17, (_) => FocusNode());
  List<TextEditingController> pollCont =
      List.generate(17, (_) => TextEditingController());

  File imageFile, videoFile;

  CreationType creationType = CreationType.image;
  bool uploadable = false, showingStory = false;
  List selectedTags = [];

  @override
  void initState() {
    if (widget.image != null) imageFile = widget.image;
    if (widget.video != null) {
      creationType = CreationType.video;
      videoFile = widget.video;
    }
    if (widget.text != null) {
      creationType = CreationType.story;
      storyCont.text = widget.text;
    }
    if (widget.poll != null) {
      creationType = CreationType.poll;
      int i = 0;
      for (String t in widget.poll) {
        pollCont[i].text = t;
        i++;
        if (i >= pollCont.length) break;
      }
    }
    uploadable = testUpload();
    super.initState();
  }

  @override
  void dispose() {
    if (imageFile != null) imageFile.deleteSync();
    if (videoFile != null) videoFile.deleteSync();
    imageFile = null;
    videoFile = null;
    super.dispose();
  }

  Widget getBodyType() {
    switch (creationType) {
      case CreationType.poll:
        return poll();
      case CreationType.story:
        return storyField();
      default:
        bool image = creationType == CreationType.image;
        if ((videoFile == null && !image) || (imageFile == null && image)) {
          return picker(image);
        }
        return Stack(
          children: [
            Center(
                child: (image)
                    ? MyPictureHolder(Image.file(imageFile))
                    : MyVideoPlayer(Key('Create'), videoFile, true)),
            ((image)
                    ? imageFile.statSync().size > 10485760
                    : videoFile.statSync().size > 10485760)
                ? Positioned(
                    left: 10,
                    top: 10,
                    child: IconButton(
                      color: Color(0xffff0000),
                      icon: Icon(Icons.info_outline_rounded),
                      onPressed: () {
                        lightImpact();
                        showDialog(
                            context: context,
                            child: Dialog(
                              shape: rRect,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                    'That\s quite the package you got there. Too bad the max is 10Mb.',
                                    textAlign: TextAlign.center),
                              ),
                            ));
                      },
                    ),
                  )
                : Container(),
            // (image)
            //     ? Positioned(
            //         left: 10,
            //         bottom: 10,
            //         child: IconButton(
            //           icon: Icon(Icons.edit_rounded),
            //           onPressed: () {
            //             lightImpact();
            //             Navigator.push(
            //               context,
            //               MaterialPageRoute(builder: (context) => EditorPage(creationType)),
            //             );
            //           },
            //         ),
            //       )
            //     : Container(),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    checkSize(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(creationType.toString().substring(13).capitalizeFirst),
        actions: [
          IconButton(
              icon: Icon(Icons.info_outline_rounded),
              onPressed: () {
                lightImpact();
                showDialog(
                    context: context,
                    child: Dialog(
                      shape: rRect,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListView(
                          shrinkWrap: true,
                          physics: ClampingScrollPhysics(),
                          children: [MyText(info())],
                        ),
                      ),
                    ));
              })
        ],
      ),
      floatingActionButton: fab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Stack(
              children: [
                getBodyType(),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: deleteData(),
                )
              ],
            ),
          ),
          commentField(),
          tagList(),
          bottomBar()
        ],
      ),
      bottomSheet: Container(height: 0),
    );
  }

  Widget deleteData() {
    Function action;
    switch (creationType) {
      case CreationType.image:
        if (imageFile != null)
          action = () {
            imageFile.deleteSync();
            imageFile = null;
          };
        break;
      case CreationType.video:
        if (videoFile != null)
          action = () {
            videoFile.deleteSync();
            videoFile = null;
          };
        break;
      case CreationType.poll:
        if (pollCont.any((e) => e.text.isNotEmpty))
          action = () => pollCont.forEach((element) => element.clear());
        break;
      case CreationType.story:
        if (storyCont.text.isNotEmpty) action = () => storyCont.clear();
        break;
    }
    if (action == null) return Container();
    return IconButton(
      icon: Icon(Icons.delete_rounded),
      onPressed: () {
        lightImpact();
        action();
        uploadable = testUpload();
        setState(() {});
      },
    );
  }

  String info() {
    String base = 'Welcome to the creation Page! ' +
        'You can upload an image, video, poll, or story. ' +
        'Tag your post with the small blue buttons. ' +
        'You can also leave the first comment if you\'d like.\n\n';
    switch (creationType) {
      case CreationType.story:
        base += 'To customize text use {curly braces} and |poles|.\n' +
            'Example: {text|tag} text2 {text3|tag|tag|tag}.\n' +
            'Hit the eye button to see what your story currently looks like.\n' +
            '(Note if it\'s just a link it will show up differently when posted)\n\n' +
            "All Tags and meanings: \n'b'=bold\n'i'=italic\n" +
            "'o'=overline\n'u'=underline\n's'=strikethrough\n'wavy'=wavy lines\n" +
            "'dd'=double lines\n'any int'=size\n\n" +
            'Any hex viable tag starting with 0x is the text color.\n\n' +
            'So 0xffffffff is white and 0xff000000 is black and 0x0 is clear.\n\n' +
            'Background color is the same except start it with 1x.\n\n' +
            'Links will be auto detected however you can force a link with a lowercase \'L\'.';
        break;
      case CreationType.poll:
        base += 'Polls use customizable text.(see story info) ' +
            'You need a minimum of one question and two answers to make a complete poll. ' +
            'There\'s a max of 16 answers. (Just leave them blank if you don\'t need them.)';
        break;
      default:
        base +=
            'For videos and images you can either select one from your camera roll or record one. ' +
                'The max size is 10mb or 10485760 bytes';
    }
    return base;
  }

  Widget poll() => ListView.builder(
        itemCount: pollCont.length,
        itemBuilder: (c, i) => Padding(
          padding: (i == 0)
              ? EdgeInsets.all(8.0)
              : EdgeInsets.fromLTRB(24, 4, 24, 4),
          child: TextField(
            controller: pollCont[i],
            focusNode: pollFocus[i],
            autofocus: i == 0,
            textAlign: TextAlign.center,
            textAlignVertical: TextAlignVertical.center,
            maxLines: 2,
            decoration: decal(hintText: (i == 0) ? 'Your Question' : '$i'),
            onTap: () => focusing(pollFocus[i]),
            onChanged: (t) => setState(() => uploadable = testUpload()),
            textInputAction: (i == pollCont.length - 1)
                ? TextInputAction.done
                : TextInputAction.next,
            onSubmitted: (i == pollCont.length - 1)
                ? (t) => pollFocus[i].unfocus()
                : (t) => pollFocus[i + 1].requestFocus(),
          ),
        ),
      );

  Widget picker(bool image) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (bool cam in [true, false])
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment((cam) ? -0.7 : -1.7, -1),
                      radius: 3,
                      colors: [
                        Theme.of(context).indicatorColor,
                        Theme.of(context).buttonColor
                      ],
                    ),
                    borderRadius: BorderRadius.circular(50)),
                height: double.infinity,
                margin: const EdgeInsets.all(8.0),
                child: RaisedButton(
                  shape: rRect,
                  color: Color(0),
                  elevation: 0,
                  onPressed: () => setMedia(image, cam),
                  child: Icon(
                    (cam) ? Icons.camera_alt : Icons.apps,
                    size: screenSize.width * 0.3,
                  ),
                ),
              ),
            ),
        ],
      );

  setMedia(bool image, bool cam) async {
    ImageSource source = ImageSource.gallery;
    if (cam) source = ImageSource.camera;
    if (image) {
      await ImagePicker()
          .getImage(source: source)
          .then((f) => imageFile = File(f.path));
    } else {
      await ImagePicker()
          .getVideo(source: source)
          .then((f) => videoFile = File(f.path));
    }
    uploadable = testUpload();
    setState(() {});
  }

  Widget tagList() => (tags == null)
      ? Container()
      : Container(
          height: 50,
          color: Theme.of(context).scaffoldBackgroundColor,
          child: ListView.builder(
            itemCount: tags.length,
            scrollDirection: Axis.horizontal,
            itemBuilder: (BuildContext c, int i) {
              String tag = '${tags[i]}';
              return Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: RaisedButton(
                  shape: rRect,
                  color:
                      (selectedTags.contains(tag)) ? Color(0xff11bb55) : null,
                  onPressed: () => setState(() {
                    lightImpact();
                    if (!selectedTags.remove(tag)) selectedTags.add(tag);
                  }),
                  child: Text(tag),
                ),
              );
            },
          ),
        );

  Widget storyField() => Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(8),
            child: (showingStory)
                ? MyText(storyCont.text)
                : TextField(
                    autofocus: true,
                    controller: storyCont,
                    focusNode: storyFocus,
                    textAlign: TextAlign.center,
                    maxLines: 50,
                    decoration: decal(),
                    onTap: () => focusing(storyFocus),
                    onChanged: (t) => setState(() => uploadable = testUpload()),
                  ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: IconButton(
              icon: Icon((showingStory)
                  ? Icons.import_contacts
                  : Icons.remove_red_eye_rounded),
              onPressed: () {
                lightImpact();
                setState(() => showingStory = !showingStory);
              },
            ),
          )
        ],
      );

  Widget commentField() => Container(
        padding: EdgeInsets.all(8),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: TextField(
          controller: commentCont,
          focusNode: commentFocus,
          textAlign: TextAlign.center,
          maxLines: (commentFocus.hasFocus) ? null : 1,
          decoration: decal(hintText: 'Comment'),
          onTap: () => setState(() => focusing(commentFocus)),
        ),
      );

  focusing(FocusNode focus) =>
      (focus.hasFocus) ? focus.unfocus() : focus.requestFocus();

  Widget fab() {
    if (uploadable)
      return Padding(
        padding: EdgeInsets.only(
            bottom: ((MediaQuery.of(context).viewInsets.bottom ?? 0) > 10)
                ? AppBar().preferredSize.height
                : 0),
        child: FloatingActionButton(
          heroTag: 69,
          onPressed: () async => await upload(),
          child: Icon(Icons.upload_rounded),
        ),
      );
    return null;
  }

  List<IconData> _icons = [
    Icons.image,
    Icons.play_circle_filled,
    Icons.poll,
    Icons.import_contacts
  ];

  Widget bottomBar() {
    List<BottomNavigationBarItem> items = List.generate(4, (i) {
      return BottomNavigationBarItem(
        icon: Icon(_icons[i]),
        label: CreationType.values[i].toString().substring(13).capitalizeFirst,
      );
    });
    if (uploadable)
      items.add(BottomNavigationBarItem(label: '', icon: Container()));
    return Theme(
      data: Theme.of(context)
          .copyWith(canvasColor: Theme.of(context).bottomAppBarColor),
      child: BottomNavigationBar(
        currentIndex: CreationType.values.indexOf(creationType),
        selectedItemColor: Theme.of(context).indicatorColor,
        unselectedItemColor: Theme.of(context).primaryColorLight,
        onTap: (i) async {
          lightImpact();
          if (i == 4) return;
          creationType = CreationType.values[i];
          setState(() => uploadable = testUpload());
        },
        items: items,
      ),
    );
  }

  bool testUpload() {
    switch (creationType) {
      case CreationType.image:
        if (imageFile != null) return imageFile.statSync().size < 10485760;
        break;
      case CreationType.video:
        if (videoFile != null) return videoFile.statSync().size < 10485760;
        break;
      case CreationType.poll:
        return pollCont.where((t) => t.text.trim().isNotEmpty).length > 2 &&
            pollCont[0].text.trim().isNotEmpty;
      case CreationType.story:
        return storyCont.text.trim().isNotEmpty;
    }
    return false;
  }

  Future upload() async {
    lightImpact();
    if (selectedTags.contains('Music') && creationType != CreationType.video) {
      return showDialog(
          context: context,
          child: Dialog(
            shape: rRect,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'The day you have a' +
                    ((creationType == CreationType.image) ? 'n ' : ' ') +
                    creationType.toString().substring(13) +
                    ' make music is the day I remove this warning.',
                textAlign: TextAlign.center,
              ),
            ),
          ));
    }
    showDialog(
        context: context,
        barrierDismissible: false,
        child: Center(child: Loading(screenSize.width)));
    String _now =
        '${DateTime.now().toUtc()}'.replaceAll('.', '').replaceAll('Z', '');
    Map<String, dynamic> data = {
      'likes': {myID: true},
      'tags': selectedTags
    };
    if (commentCont.text.trim().isNotEmpty) {
      data[_now + '-' + myID] = [
        commentCont.text,
        {myID: true}
      ];
    }
    String _docTitle = '${_now.substring(11, 19)}-${types[creationType]}-$myID';
    switch (creationType) {
      case CreationType.story:
        data['story'] = storyCont.text;
        break;
      case CreationType.poll:
        data['question'] = pollCont[0].text;
        pollCont
            .sublist(1)
            .where((t) => t.text.trim().isNotEmpty)
            .forEach((t) => data['answer:' + t.text] = []);
        break;
      default:
        await FirebaseStorage.instance
            .ref()
            .child(_now.substring(0, 4))
            .child(_now.substring(5, 7))
            .child(_now.substring(0, 10))
            .child(_docTitle)
            .putFile(
                (creationType == CreationType.image) ? imageFile : videoFile)
            .then(
                (d) => d.ref.getDownloadURL().then((url) => data['url'] = url));
        String _tmpPath = tmpPath + '/$_now--$_docTitle.';
        imageFile?.copySync(_tmpPath + 'png');
        imageFile?.deleteSync();
        imageFile = null;
        videoFile?.copySync(_tmpPath + 'mp4');
        videoFile?.deleteSync();
        videoFile = null;
        break;
    }
    FirebaseFirestore fire = FirebaseFirestore.instance;
    WriteBatch _batch = fire.batch();
    DocumentReference _ref =
        fire.collection(_now.substring(0, 10)).doc(_docTitle);
    _batch.set(_ref, data);
    _batch.set(
        fire.collection('0000').doc(myID),
        {
          'posts': FieldValue.arrayUnion([_ref])
        },
        SetOptions(merge: true));
    readChild = null;
    await _batch.commit();
    Navigator.of(context).pop();
    Navigator.of(context).pop();
  }
}
