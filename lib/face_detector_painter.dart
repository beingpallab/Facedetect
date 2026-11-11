import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorPainter extends CustomPainter {
  final List<Face> faces;
  final ui.Image image;

  FaceDetectorPainter({required this.faces, required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    final Paint labelBackground = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Calculate scale factors between actual image size and displayed widget size
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;

    for (int i = 0; i < faces.length; i++) {
      final Face face = faces[i];
      final Rect rect = face.boundingBox;

      // Scale coordinates to fit UI preview
      final Rect scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      // Draw rectangular bounding box around face
      canvas.drawRect(scaledRect, paint);

      // Draw face label index tag on top of the bounding box
      final textSpan = TextSpan(
        text: 'Face ${i + 1}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      final Offset labelOffset = Offset(
        scaledRect.left.clamp(0, size.width - textPainter.width),
        (scaledRect.top - 20).clamp(0, size.height - textPainter.height),
      );

      final Rect backgroundRect = Rect.fromLTWH(
        labelOffset.dx - 4,
        labelOffset.dy - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
        labelBackground,
      );
      textPainter.paint(canvas, labelOffset);
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.faces != faces;
  }
}