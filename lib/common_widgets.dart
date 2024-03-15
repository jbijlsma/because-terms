import 'package:flutter/services.dart';

class Document {
  final String title;
  final int titleBottomMargin;
  final int padding;
  final List<ChildWidget> children;
  final List<TxtStyle> styles;

  void addChild(ChildWidget child) {
    children.add(child);
  }

  Document(this.title, this.titleBottomMargin, this.padding, this.children,
      this.styles);
}

abstract class ChildWidget {}

class Paragraph extends ChildWidget {
  final List<Txt> texts;

  Paragraph(this.texts);
}

class Txt extends ChildWidget {
  final String text;
  final String styleId;

  Txt(this.text, this.styleId);
}

class CheckBox extends ChildWidget {
  final String text;
  final String styleId;

  CheckBox(this.text, this.styleId);
}

class Img extends ChildWidget {
  final Uint8List bytes;

  Img(this.bytes);
}

class Spacer extends ChildWidget {
  final int height;

  Spacer(this.height);
}

extension ColorX on Color {
  String toHexTriplet() =>
      '#${(value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class TxtStyle {
  final String id;
  final Color? color;
  final bool? isBold;
  final int? fontSize;

  TxtStyle(this.id, {this.color, this.isBold, this.fontSize});
}
