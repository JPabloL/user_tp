import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum PillStatus { verified, pending, rejected, pro, custom }

class StatusPill extends StatelessWidget {
  final PillStatus status;
  final String? customText;
  final Color? customColor;

  const StatusPill({
    super.key,
    required this.status,
    this.customText,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    Color baseColor;
    String text;
    bool isPro = status == PillStatus.pro;

    switch (status) {
      case PillStatus.verified:
        baseColor = const Color(0xFF22C55E); // Green
        text = 'VERIFICADO';
        break;
      case PillStatus.pending:
        baseColor = const Color(0xFFF59E0B); // Amber
        text = 'PENDIENTE';
        break;
      case PillStatus.rejected:
        baseColor = const Color(0xFFEF4444); // Red
        text = 'RECHAZADO';
        break;
      case PillStatus.pro:
        baseColor = const Color(0xFFFFDE00); // Yellow
        text = 'PRO';
        break;
      case PillStatus.custom:
        baseColor = customColor ?? Colors.grey;
        text = customText ?? '';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: baseColor,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: isPro
            ? GoogleFonts.oswald(
                color: baseColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              )
            : GoogleFonts.outfit(
                color: baseColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
      ),
    );
  }
}
