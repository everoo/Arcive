import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:arcive/Globals.dart';
import 'package:arcive/misc/PictureHolder.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'Loading.dart';

class MyVideoPlayer extends StatefulWidget {
  final Key key;
  final File videoFile;
  final bool playing;

  MyVideoPlayer(this.key, this.videoFile, this.playing);

  @override
  _MyVideoPlayerState createState() => _MyVideoPlayerState();
}

class _MyVideoPlayerState extends State<MyVideoPlayer> {
  Widget child;
  bool notSeeking = true;

  @override
  void initState() {
    asyncInit();
    super.initState();
  }

  @override
  dispose() {
    asyncDispose();
    super.dispose();
  }

  listener() {
    if (mounted)
      setState(() {});
    else
      asyncDispose();
  }

  VideoPlayerController cont() =>
      (widget.key == Key('Create')) ? createCont : vidCont;

  asyncInit() async {
    VideoPlayerController controller =
        VideoPlayerController.file(widget.videoFile);
    await controller.initialize();
    await controller.setLooping(true);
    if (autoPlayVids && widget.playing) controller.play();
    controller.addListener(listener);
    if (widget.key == Key('Create'))
      createCont = controller;
    else
      vidCont = controller;
    setState(
      () => child = Center(
        child: AspectRatio(
          child: VideoPlayer(controller),
          aspectRatio: controller.value.aspectRatio,
        ),
      ),
    );
  }

  asyncDispose() async {
    child = null;
    if (cont() != null) {
      cont().removeListener(listener);
      await cont().pause();
      await cont().dispose();
      if (widget.key == Key('Create'))
        createCont = null;
      else
        vidCont = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (child == null) return Loading(screenSize.width - 16);
    return Column(
      children: <Widget>[
        Expanded(
          child: GestureDetector(
            child: MyPictureHolder(Container(child: child, color: Color(0))),
            onTap: () {
              lightImpact();
              (cont().value.isPlaying) ? cont().pause() : cont().play();
            },
          ),
        ),
        Container(
          color: Theme.of(context).secondaryHeaderColor,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Slider(
                  max: cont().value.duration.inMilliseconds.toDouble(),
                  onChanged: (d) => seek(d.toInt()),
                  value: min(
                    max(0, cont().value.position.inMilliseconds.toDouble()),
                    cont().value.duration.inMilliseconds.toDouble(),
                  ),
                ),
              ),
              Text(
                (cont().value.duration == null)
                    ? '0:00/0:00'
                    : cont().value.position.toString().substring(3, 7) +
                        '/' +
                        cont().value.duration.toString().substring(3, 7),
              ),
              Container(width: 20)
            ],
          ),
        ),
      ],
    );
  }

  seek(int d) async {
    if (notSeeking) {
      notSeeking = false;
      await cont().seekTo(Duration(milliseconds: d));
      await cont().play();
      Timer(Duration(milliseconds: 30), () async {
        await cont().pause();
        notSeeking = true;
      });
    }
  }
}
