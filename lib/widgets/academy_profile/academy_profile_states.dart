import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';

/// Placeholder de tab para Parte 1 del perfil de academia.
class AcademyProfileTabPlaceholder extends StatefulWidget {
  const AcademyProfileTabPlaceholder({
    super.key,
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  State<AcademyProfileTabPlaceholder> createState() =>
      _AcademyProfileTabPlaceholderState();
}

class _AcademyProfileTabPlaceholderState extends State<AcademyProfileTabPlaceholder>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      key: PageStorageKey<String>('academy_tab_${widget.label}'),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 42,
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.label.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.oswald(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contenido en construcción.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AcademyProfileErrorState extends StatelessWidget {
  const AcademyProfileErrorState({
    super.key,
    this.title = 'NO SE PUDO CARGAR LA ACADEMIA',
    this.message = 'No pudimos obtener la información en este momento.',
    required this.onRetry,
    required this.isRetrying,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: 0.22),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.oswald(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: isRetrying ? null : onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brandTeal,
                foregroundColor: const Color(0xFF0B101E),
                disabledBackgroundColor:
                    AppTheme.brandTeal.withValues(alpha: 0.45),
              ),
              child: isRetrying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0B101E),
                      ),
                    )
                  : Text(
                      'REINTENTAR',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
