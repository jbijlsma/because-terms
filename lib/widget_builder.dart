import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class Document {
  final String title;
  final int padding;
  final List<ChildWidget> children;
  final List<TxtStyle> styles;

  void addChild(ChildWidget child) {
    children.add(child);
  }

  Document(this.title, this.padding, this.children, this.styles);
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

class PdfBuilder {
  final Map<String, pw.TextStyle> _stylesById = {};
  late Document _doc;

  PdfBuilder(Document doc) {
    _doc = doc;
    _createStyles();
  }

  void _createStyles() {
    for (final style in _doc.styles) {
      _stylesById[style.id] = _createStyle(style);
    }
  }

  pw.TextStyle _createStyle(TxtStyle style) {
    var textStyle = pw.TextStyle(
        color: PdfColor.fromHex(
          style.color!.toHexTriplet(),
        ),
        fontSize: style.fontSize?.toDouble(),
        fontWeight:
            style.isBold == null || !style.isBold! ? null : pw.FontWeight.bold);

    return textStyle;
  }

  pw.Widget _buildChild(ChildWidget child) {
    switch (child) {
      case final Paragraph paragraph:
        return _buildParagraph(paragraph);
      case final CheckBox cb:
        return _buildCheckBox(cb);
      case final Txt txt:
        return _buildText(txt);
      case final Img img:
        return _buildImg(img);
      case final Spacer spacer:
        return _buildSpacer(spacer);
      default:
        throw UnimplementedError('Unknown child: $child');
    }
  }

  pw.Widget _buildImg(Img img) {
    return pw.Image(pw.MemoryImage(img.bytes));
  }

  pw.Widget _buildText(Txt txt) {
    return pw.Text(
      txt.text,
      textAlign: pw.TextAlign.center,
      style: _stylesById[txt.styleId],
    );
  }

  pw.TextSpan _buildTextSpan(Txt txt) {
    return pw.TextSpan(text: txt.text, style: _stylesById[txt.styleId]);
  }

  pw.Widget _buildParagraph(Paragraph p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          children: p.texts.map((txt) => _buildTextSpan(txt)).toList(),
        ),
      ),
    );
  }

  pw.Widget _buildCheckBox(CheckBox cb) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          cb.text,
          style: _stylesById[cb.styleId],
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
          child: pw.Checkbox(value: true, name: 'cb'),
        ),
      ],
    );
  }

  pw.Widget _buildSpacer(Spacer spacer) {
    return pw.SizedBox(height: spacer.height.toDouble());
  }

  Future<pw.Document> build() async {
    final pdf = pw.Document();
    final logoImg = await rootBundle.load('assets/because_logo.webp');
    final logoBytes = logoImg.buffer.asUint8List();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                height: 75,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex("#5BC6C2"),
                  image: pw.DecorationImage(
                      image: pw.MemoryImage(logoBytes),
                      fit: pw.BoxFit.fitHeight),
                ),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.all(_doc.padding.toDouble()),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    _buildText(Txt(_doc.title, 'title')),
                    pw.SizedBox(height: 20),
                    ..._doc.children.map((c) => _buildChild(c)).toList(),
                  ],
                ),
              )
            ],
          ); // Center
        },
      ),
    );

    return pdf;
  }
}
