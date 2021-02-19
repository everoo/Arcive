import 'package:arcive/Globals.dart';
import 'package:flutter/material.dart';

// ignore: must_be_immutable
class Filter extends StatefulWidget {
  List<String> selectedTags, selectedTypes;
  List<int> nums;

  Filter(this.selectedTags, this.selectedTypes, this.nums);

  @override
  _FilterState createState() => _FilterState();
}

class _FilterState extends State<Filter> {
  int n;

  @override
  Widget build(BuildContext context) {
    n = 0;
    return Dialog(
      shape: rRect,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: screenSize.height * 0.4,
              child: ListView(children: [
                Text('Tags: ', textAlign: TextAlign.center),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (String tag in tags.sublist(1))
                      Padding(
                        padding: EdgeInsets.all(4),
                        child: RaisedButton(
                            shape: rRect,
                            onPressed: () => setState(() {
                                  lightImpact();
                                  if (!widget.selectedTags.remove(tag))
                                    widget.selectedTags.add(tag);
                                }),
                            color: (widget.selectedTags.contains(tag))
                                ? Color(0xff11bb55)
                                : null,
                            child: Text(tag)),
                      )
                  ],
                ),
                Text('Types: ', textAlign: TextAlign.center),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (String type in [
                      'stories',
                      'polls',
                      'images',
                      'videos'
                    ])
                      Padding(
                        padding: EdgeInsets.all(4),
                        child: RaisedButton(
                            shape: rRect,
                            onPressed: () => setState(() {
                                  lightImpact();
                                  if (!widget.selectedTypes.remove(type))
                                    widget.selectedTypes.add(type);
                                }),
                            color: (widget.selectedTypes.contains(type))
                                ? Color(0xff11bb55)
                                : null,
                            child: Text(type.capitalizeFirst)),
                      )
                  ],
                ),
                for (String t in ['Likes', 'Dislikes', 'Comments'])
                  Column(children: [
                    Container(height: 8),
                    Text(t + ': '),
                    numFilter()
                  ]),
              ]),
            ),
            Column(
              children: [
                for (List<String> n in [
                  ['Save Filters', 'Load Filters'],
                  ['Clear', 'Filter']
                ])
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (String s in n)
                        RaisedButton(
                          onPressed: () => action(s),
                          child: Text(s),
                          shape: rRect,
                        ),
                    ],
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  action(String i) {
    lightImpact();
    switch (i) {
      case 'Clear':
        widget.selectedTags.clear();
        widget.selectedTypes.clear();
        widget.nums = List.generate(6, (_) => null);
        break;
      case 'Filter':
        return Navigator.of(context).pop(true);
      case 'Load Filters':
        dynamic data = PersistentData().getData('filters');
        if (data == null) {
          action('Clear');
        } else {
          widget.selectedTags = [for (var v in data[0]) '$v'];
          widget.selectedTypes = [for (var v in data[1]) '$v'];
          widget.nums = [for (var v in data[2]) int.tryParse('$v')];
        }
        break;
      case 'Save Filters':
        return PersistentData().writeData({
          'filters': [widget.selectedTags, widget.selectedTypes, widget.nums]
        });
    }
    setState(() {});
  }

  numFilter() => Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('More than'),
            numField(n++),
            Text('but less than'),
            numField(n++)
          ]);

  numField(int i) => Container(
        padding: EdgeInsets.all(3),
        width: 70,
        height: 40,
        child: TextField(
          controller:
              TextEditingController(text: (widget.nums[i] ?? '').toString()),
          maxLines: 1,
          decoration: decal(),
          keyboardType: TextInputType.number,
          onChanged: (t) => widget.nums[i] = int.tryParse(t),
        ),
      );
}
