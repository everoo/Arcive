import 'package:arcive/Globals.dart';
import 'package:arcive/misc/Loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class MyPictureHolder extends StatefulWidget {
  final Widget child;

  const MyPictureHolder(this.child);

  @override
  _MyPictureHolderState createState() => _MyPictureHolderState();
}

class _MyPictureHolderState extends State<MyPictureHolder>
    with SingleTickerProviderStateMixin {
  Offset aS = Offset(0, 1);
  Offset startAS, startPoint;
  Offset point = Offset(0, 0);

  AnimationController _anime;
  Animation<Offset> _ani;

  void _runAnimation(Offset end) {
    _ani = _anime.drive(Tween(begin: point, end: end));
    const spring = SpringDescription(mass: 30, stiffness: 1, damping: 1);
    final simulation = SpringSimulation(spring, 0, 1, 0);
    _anime.animateWith(simulation);
  }

  @override
  void initState() {
    super.initState();
    _anime = AnimationController(vsync: this)
      ..addListener(() => setState(() => point = _ani.value));
  }

  @override
  void dispose() {
    _anime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child == null) return Loading(screenSize.width - 16);
    return GestureDetector(
      onDoubleTap: () {
        lightImpact();
        aS = Offset(0, 1);
        _runAnimation(Offset.zero);
      },
      onScaleStart: (d) {
        _anime.stop();
        startPoint = d.focalPoint - point;
        startAS = aS;
      },
      onScaleUpdate: (d) => setState(() {
        aS = Offset(startAS.dx + d.rotation, startAS.dy * d.scale);
        point = d.focalPoint - startPoint;
      }),
      onScaleEnd: (s) => _runAnimation(point + s.velocity.pixelsPerSecond / 7),
      child: Container(
        color: Colors.transparent,
        child: Transform.translate(
            child: Transform.scale(
                child: Transform.rotate(child: widget.child, angle: aS.dx),
                scale: aS.dy),
            offset: point),
      ),
    );
  }
}
