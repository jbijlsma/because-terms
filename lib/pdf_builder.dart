import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import './common_widgets.dart' as cw;

class PdfBuilder {
  final Map<String, pw.TextStyle> _stylesById = {};
  late cw.Document _doc;

  PdfBuilder(cw.Document doc) {
    _doc = doc;
    _createStyles();
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
                    _buildText(cw.Txt(_doc.title, 'title')),
                    _buildSpacer(cw.Spacer(_doc.titleBottomMargin)),
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

  pw.Widget _buildChild(cw.ChildWidget child) {
    switch (child) {
      case final cw.Paragraph paragraph:
        return _buildParagraph(paragraph);
      case final cw.CheckBox cb:
        return _buildCheckBox(cb);
      case final cw.Txt txt:
        return _buildText(txt);
      case final cw.Img img:
        return _buildImg(img);
      case final cw.Spacer spacer:
        return _buildSpacer(spacer);
      default:
        throw UnimplementedError('Unknown child: $child');
    }
  }

  pw.Widget _buildImg(cw.Img img) {
    return pw.Image(pw.MemoryImage(img.bytes));
  }

  pw.Widget _buildText(cw.Txt txt) {
    return pw.Text(
      txt.text,
      textAlign: pw.TextAlign.center,
      style: _stylesById[txt.styleId],
    );
  }

  pw.TextSpan _buildTextSpan(cw.Txt txt) {
    return pw.TextSpan(text: txt.text, style: _stylesById[txt.styleId]);
  }

  pw.Widget _buildParagraph(cw.Paragraph p) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: pw.RichText(
        text: pw.TextSpan(
          children: p.texts.map((txt) => _buildTextSpan(txt)).toList(),
        ),
      ),
    );
  }

  pw.Widget _buildCheckBox(cw.CheckBox cb) {
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

  pw.Widget _buildSpacer(cw.Spacer spacer) {
    return pw.SizedBox(height: spacer.height.toDouble());
  }

  void _createStyles() {
    for (final style in _doc.styles) {
      _stylesById[style.id] = _createStyle(style);
    }
  }

  pw.TextStyle _createStyle(cw.TxtStyle style) {
    var textStyle = pw.TextStyle(
        color: PdfColor.fromHex(
          style.color!.toHexTriplet(),
        ),
        fontSize: style.fontSize?.toDouble(),
        fontWeight:
            style.isBold == null || !style.isBold! ? null : pw.FontWeight.bold);

    return textStyle;
  }
}
