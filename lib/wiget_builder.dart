import 'dart:ui';

import 'package:flutter/material.dart' as m;

import './common_widgets.dart' as cw;

class WidgetBuilder {
  final Map<String, m.TextStyle> _stylesById = {};
  late cw.Document _doc;

  WidgetBuilder(cw.Document doc) {
    _doc = doc;
    _createStyles();
  }

  List<m.Widget> build() {
    List<m.Widget> children = [];

    children.add(_buildText(cw.Txt(_doc.title, 'title')));
    children.add(_buildSpacer(cw.Spacer(_doc.titleBottomMargin)));

    for (final docChild in _doc.children) {
      children.add(_buildChild(docChild));
    }

    return children;
  }

  m.Widget _buildChild(cw.ChildWidget child) {
    switch (child) {
      case final cw.Paragraph paragraph:
        return _buildParagraph(paragraph);
      case final cw.Txt txt:
        return _buildText(txt);
      case final cw.Spacer spacer:
        return _buildSpacer(spacer);
      default:
        throw UnimplementedError('Unknown child: $child');
    }
  }

  m.Widget _buildText(cw.Txt txt) {
    return m.Text(
      txt.text,
      textAlign: TextAlign.center,
      style: _stylesById[txt.styleId],
    );
  }

  m.TextSpan _buildTextSpan(cw.Txt txt) {
    return m.TextSpan(text: txt.text, style: _stylesById[txt.styleId]);
  }

  m.Widget _buildParagraph(cw.Paragraph p) {
    return m.Padding(
      padding: const m.EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: m.RichText(
        text: m.TextSpan(
          children: p.texts.map((txt) => _buildTextSpan(txt)).toList(),
        ),
      ),
    );
  }

  m.Widget _buildSpacer(cw.Spacer spacer) {
    return m.SizedBox(height: spacer.height.toDouble());
  }

  void _createStyles() {
    for (final style in _doc.styles) {
      _stylesById[style.id] = _createStyle(style);
    }
  }

  m.TextStyle _createStyle(cw.TxtStyle style) {
    var textStyle = m.TextStyle(
        color: style.color,
        fontSize: style.fontSize?.toDouble(),
        fontWeight:
            style.isBold == null || !style.isBold! ? null : FontWeight.bold);

    return textStyle;
  }
}
