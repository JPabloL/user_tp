import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double width;
  final bool isSecondary;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width = double.infinity,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: (isSecondary || onPressed == null)
            ? null
            : [
                BoxShadow(
                  color: AppTheme.brandTeal.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppTheme.brandTeal.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 8,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? Colors.transparent : AppTheme.brandTeal,
          foregroundColor: isSecondary ? AppTheme.brandTeal : AppTheme.navyPrimary,
          elevation: 0,
          side: isSecondary
              ? const BorderSide(color: AppTheme.brandTeal, width: 1.5)
              : BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: isSecondary ? Colors.transparent : Colors.grey[800],
        ),
        child: isLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSecondary ? AppTheme.brandTeal : AppTheme.navyPrimary,
                  ),
                ),
              )
            : Text(
                text.toUpperCase(),
                style: GoogleFonts.oswald(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }
}
