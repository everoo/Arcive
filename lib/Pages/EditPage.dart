// import 'dart:math';
// import 'dart:typed_data';
// import 'dart:ui' as ui;

// import 'package:arcive/Globals.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:image_editor/image_editor.dart';

// class EditorPage extends StatefulWidget {
//   final CreationType type;

//   const EditorPage(this.type);
//   @override
//   _EditorPageState createState() => _EditorPageState();
// }

// class _EditorPageState extends State<EditorPage> {
//   GlobalKey _globalKey = new GlobalKey();
//   Uint8List imageBytes;
//   List<List<Offset>> _lines = [];
//   Paint _paint = Paint()
//     ..color = Colors.blue
//     ..style = PaintingStyle.stroke
//     ..strokeWidth = 3;

//   List<EditingWidget> children = [];

//   List<IconData> _icons = [
//     Icons.undo_rounded,
//     Icons.text_fields_rounded,
//     Icons.add_a_photo_rounded,
//     Icons.crop_rounded,
//     Icons.colorize_rounded,
//     Icons.save_alt_rounded,
//     Icons.delete_forever_rounded
//   ];

//   @override
//   Widget build(BuildContext context) {
//     checkSize(context);
//     return Scaffold(
//       appBar: AppBar(
//           title: Text(
//         'Edit ' + widget.type.toString().substring(13).capitalizeFirst,
//       )),
//       body: Column(
//         children: [
//           Expanded(
//             child: Container(
//               height: screenSize.height * 0.8,
//               width: screenSize.width,
//               child: RepaintBoundary(
//                   key: _globalKey,
//                   child: Stack(
//                     children: [
//                       GestureDetector(
//                         onPanStart: (d) =>
//                             setState(() => _lines.add([d.localPosition])),
//                         onPanUpdate: (d) =>
//                             setState(() => _lines.last.add(d.localPosition)),
//                         child: Container(
//                           color: Color(0),
//                           child: Stack(
//                             children: [
//                               (imageBytes == null)
//                                   ? Container()
//                                   : Image.memory(imageBytes),
//                               for (List<Offset> line in _lines)
//                                 CustomPaint(painter: DrawLines(line, _paint)),
//                             ],
//                           ),
//                         ),
//                       ),
//                       for (EditingWidget ch in children) ch,
//                     ],
//                   )),
//             ),
//           ),
//           Container(
//             height: screenSize.height * 0.1,
//             child: ListView(
//               scrollDirection: Axis.horizontal,
//               children: [
//                 for (int i in List.generate(_icons.length, (i) => i))
//                   Padding(
//                     padding: EdgeInsets.all(4),
//                     child: IconButton(
//                       onPressed: () {
//                         lightImpact();
//                         if (i == 0) {
//                           if (_lines.isNotEmpty) _lines.removeLast();
//                         } else if (i == 1) {
//                           children.add(EditingWidget(TextField()));
//                         } else if (i == 2) {
//                           print('image');
//                         } else if (i == 3) {
//                           print('crop');
//                         } else if (i == 4) {
//                           _paint.color = Color(Random().nextInt(0xffffffff));
//                         } else if (i == 5) {
//                           _capturePng();
//                         } else if (i ==6) {
//                           imageBytes = null;
//                         }
//                         setState(() {});
//                       },
//                       icon: Icon(_icons[i]),
//                     ),
//                   )
//               ],
//             ),
//           ),
//           Container(height: MediaQuery.of(context).viewPadding.bottom)
//         ],
//       ),
//     );
//   }

//   Future<void> _capturePng() async {
//     RenderRepaintBoundary boundary =
//         _globalKey.currentContext.findRenderObject();
//     ui.Image _image = await boundary.toImage(pixelRatio: 2.0);
//     ByteData byteData = await _image.toByteData(format: ui.ImageByteFormat.png);
//     Uint8List pngBytes = byteData.buffer.asUint8List();
//     ImageEditorOption editor = ImageEditorOption();
//     editor.addOptions([]);
//     imageBytes =
//         await ImageEditor.editImage(image: pngBytes, imageEditorOption: editor);
//     _lines.clear();
//     setState(() {});
//   }
// }

// class DrawLines extends CustomPainter {
//   final List<Offset> lines;
//   final Paint pain;

//   DrawLines(this.lines, this.pain);

//   @override
//   void paint(Canvas canvas, Size size) =>
//       canvas.drawPath(Path()..addPolygon(lines, false), pain);

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }

// class EditingWidget extends StatefulWidget {
//   final Widget child;

//   EditingWidget(this.child);

//   @override
//   _EditingWidgetState createState() => _EditingWidgetState();
// }

// class _EditingWidgetState extends State<EditingWidget> {
//   Offset aS = Offset(0, 1), t = Offset(0, 0), startT, startAS;

//   @override
//   Widget build(BuildContext context) {
//     return Transform.scale(
//       scale: aS.dy,
//       child: Transform.translate(
//         offset: t,
//         child: Transform.rotate(
//           angle: aS.dx,
//           child: GestureDetector(
//             behavior: HitTestBehavior.opaque,
//             onScaleStart: (d) => setState(() {
//               startT = d.focalPoint - t;
//               startAS = aS;
//             }),
//             onScaleUpdate: (d) => setState(() {
//               aS = Offset(startAS.dx + d.rotation, startAS.dy * d.scale);
//               t = d.focalPoint - startT;
//             }),
//             child: widget.child,
//           ),
//         ),
//       ),
//     );
//   }
// }
