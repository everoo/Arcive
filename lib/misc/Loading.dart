import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

class Loading extends StatefulWidget {
  final double size;

  Loading(this.size);

  @override
  _LoadingState createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  Paint _paint = Paint()..strokeWidth = 1;
  AnimationController _menu;
  List<List<Offset>> _points;
  double r = Random().nextDouble();
  List<Color> colors;
  // int way = 1;

  Color newColor() => Color(Random().nextInt(0xbbbbbb) + 0xff444444);

  List<Offset> newList(double rand) => List.generate(102,
      (i) => Offset(sin(i * rand) * sin(i), cos(i)) * (widget.size - 20) / 2);

  listen() => setState(
      () => _paint.color = Color.lerp(colors[0], colors[1], _menu.value));

  @override
  void initState() {
    _points = [newList(r), newList(r)];
    colors = [newColor(), newColor()];
    _menu = AnimationController(vsync: this)..addListener(listen);
    animate();
    super.initState();
  }

  animate() async {
    double z = pi / 360;
    _points = [_points[1], newList(r += z)];
    colors = [colors[1], newColor()];
    _menu.reset();
    await _menu.animateTo(1, duration: Duration(milliseconds: 1500));
    animate();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: CustomPaint(
          painter: MyPainter(_points, _paint),
          size: Size(0, _menu.value),
        ),
      );

  @override
  void dispose() {
    _menu.removeListener(listen);
    _menu.dispose();
    super.dispose();
  }
}

class MyPainter extends CustomPainter {
  final List<List<Offset>> _points;
  final Paint _paint;

  MyPainter(this._points, this._paint);

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPoints(
      PointMode.polygon,
      List.generate(
          102, (i) => Offset.lerp(_points[0][i], _points[1][i], size.height)),
      _paint);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
