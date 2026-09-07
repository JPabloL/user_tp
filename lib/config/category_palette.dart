import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta táctica por categoría.
///
/// Tokens:
/// - [base]: color principal (tiras, chips, acentos)
/// - [onBase]: texto sobre [base]
/// - [support]: variante de apoyo / fondos secundarios
/// - [onDark]: acento legible sobre fondos oscuros (UI stealth)
/// - [onLight]: acento legible sobre fondos claros
class CategoryPalette {
  static const Map<String, Map<String, Color>> _styles = {
    // INFANTILES
    'U6': {
      'base': Color(0xFFF4C542),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF6B4E00),
      'onDark': Color(0xFFF4C542),
      'onLight': Color(0xFF765800),
    },
    'U7': {
      'base': Color(0xFF1EA7FD),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF075E9E),
      'onDark': Color(0xFF1EA7FD),
      'onLight': Color(0xFF075E9E),
    },
    'U8': {
      'base': Color(0xFF39C86A),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF116B42),
      'onDark': Color(0xFF39C86A),
      'onLight': Color(0xFF126A3A),
    },
    'U9': {
      'base': Color(0xFF2DD4BF),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF0D6B63),
      'onDark': Color(0xFF2DD4BF),
      'onLight': Color(0xFF0F6E67),
    },
    'U10': {
      'base': Color(0xFFF25F5C),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF9A2C2C),
      'onDark': Color(0xFFF25F5C),
      'onLight': Color(0xFFA82B32),
    },
    'U11': {
      'base': Color(0xFFB9D83A),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF556B09),
      'onDark': Color(0xFFB9D83A),
      'onLight': Color(0xFF526500),
    },
    'U12': {
      'base': Color(0xFFF59E0B),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF9A4E00),
      'onDark': Color(0xFFF59E0B),
      'onLight': Color(0xFF9A4E00),
    },
    // SUB 12
    'FU12': {
      'base': Color(0xFFF472B6),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFFA72B78),
      'onDark': Color(0xFFF472B6),
      'onLight': Color(0xFFA62C73),
    },
    'VU12': {
      'base': Color(0xFF7C83D6),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF3F479B),
      'onDark': Color(0xFF9EA6FF),
      'onLight': Color(0xFF414896),
    },
    // SUB 14
    'U14': {
      'base': Color(0xFF2F80ED),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF124A9B),
      'onDark': Color(0xFF62A6FF),
      'onLight': Color(0xFF1457A6),
    },
    'VU14': {
      'base': Color(0xFF334EAA),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFF6D8EF5),
      'onDark': Color(0xFF7596FF),
      'onLight': Color(0xFF334EAA),
    },
    'FU14': {
      'base': Color(0xFFF4B183),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFFA4552B),
      'onDark': Color(0xFFF4B183),
      'onLight': Color(0xFF9A4D2D),
    },
    // SUB 15
    'U15': {
      'base': Color(0xFFC44569),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFF6F1E3D),
      'onDark': Color(0xFFF0779A),
      'onLight': Color(0xFF8F2146),
    },
    'VU15': {
      'base': Color(0xFF6E2142),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFFC05A86),
      'onDark': Color(0xFFD96D9D),
      'onLight': Color(0xFF6E2142),
    },
    'FU15': {
      'base': Color(0xFFF2B6CF),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFFA54A71),
      'onDark': Color(0xFFF2B6CF),
      'onLight': Color(0xFFA54A71),
    },
    // SUB 16
    'U16': {
      'base': Color(0xFF7652D4),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFF3D258D),
      'onDark': Color(0xFFA58BFF),
      'onLight': Color(0xFF4B348B),
    },
    'VU16': {
      'base': Color(0xFF382C80),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFF9580FF),
      'onDark': Color(0xFFA58BFF),
      'onLight': Color(0xFF382C80),
    },
    'FU16': {
      'base': Color(0xFFCBB9F6),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF6B54AE),
      'onDark': Color(0xFFCBB9F6),
      'onLight': Color(0xFF6B54AE),
    },
    // SUB 17
    'U17': {
      'base': Color(0xFF2A9D8F),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF0C5E58),
      'onDark': Color(0xFF4CC8B9),
      'onLight': Color(0xFF14685E),
    },
    'VU17': {
      'base': Color(0xFF0F5B63),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFF54CCC7),
      'onDark': Color(0xFF54CCC7),
      'onLight': Color(0xFF0F5B63),
    },
    'FU17': {
      'base': Color(0xFFA6E3E0),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF267D7B),
      'onDark': Color(0xFFA6E3E0),
      'onLight': Color(0xFF267D7B),
    },
    // SUB 18
    'U18': {
      'base': Color(0xFF5FAF3A),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF276B2F),
      'onDark': Color(0xFF7FD35C),
      'onLight': Color(0xFF337322),
    },
    'VU18': {
      'base': Color(0xFF1F6A43),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFF81D18B),
      'onDark': Color(0xFF8DD699),
      'onLight': Color(0xFF1F6A43),
    },
    'FU18': {
      'base': Color(0xFFBFE7C4),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF397A4B),
      'onDark': Color(0xFFBFE7C4),
      'onLight': Color(0xFF397A4B),
    },
    // SUB 21C
    'U21C': {
      'base': Color(0xFFA67716),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF58400B),
      'onDark': Color(0xFFD6A940),
      'onLight': Color(0xFF70520D),
    },
    'VU21C': {
      'base': Color(0xFF3B4453),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFF8F9AAD),
      'onDark': Color(0xFFAAB6C5),
      'onLight': Color(0xFF3B4453),
    },
    'FU21C': {
      'base': Color(0xFFC7CED8),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF53606F),
      'onDark': Color(0xFFC7CED8),
      'onLight': Color(0xFF53606F),
    },
    // MAYORES / LIBRES
    'MV': {
      'base': Color(0xFF171717),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFFDDE7F0),
      'onDark': Color(0xFFDDE7F0),
      'onLight': Color(0xFF171717),
    },
    'MF': {
      'base': Color(0xFFE76F51),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF9C2F1C),
      'onDark': Color(0xFFF28B73),
      'onLight': Color(0xFFA23C2A),
    },
    'MM': {
      'base': Color(0xFF8D3B72),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFFD987B7),
      'onDark': Color(0xFFCF78AF),
      'onLight': Color(0xFF6A2454),
    },
    'LV': {
      'base': Color(0xFF2563EB),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFFA2C8FF),
      'onDark': Color(0xFF78A7FF),
      'onLight': Color(0xFF1747A7),
    },
    'LF': {
      'base': Color(0xFF13C8B1),
      'onBase': Color(0xFF0B1323),
      'support': Color(0xFF08675F),
      'onDark': Color(0xFF37E6D0),
      'onLight': Color(0xFF08756A),
    },
    'LM': {
      'base': Color(0xFF4338CA),
      'onBase': Color(0xFFF8FAFC),
      'support': Color(0xFFA99BFF),
      'onDark': Color(0xFF9588FF),
      'onLight': Color(0xFF30247F),
    },
  };

  static const Map<String, Color> _fallbackF = {
    'base': Color(0xFFF472B6),
    'onBase': Color(0xFF0B1323),
    'support': Color(0xFFA72B78),
    'onDark': Color(0xFFF472B6),
    'onLight': Color(0xFFA62C73),
  };

  static const Map<String, Color> _fallbackV = {
    'base': Color(0xFF1F6A43),
    'onBase': Color(0xFFF8FAFC),
    'support': Color(0xFF81D18B),
    'onDark': Color(0xFF8DD699),
    'onLight': Color(0xFF1F6A43),
  };

  static const Map<String, Color> _fallbackDefault = {
    'base': Color(0xFF64748B),
    'onBase': Color(0xFFF8FAFC),
    'support': Color(0xFF334155),
    'onDark': Color(0xFF94A3B8),
    'onLight': Color(0xFF475569),
  };

  /// Devuelve el set completo de tokens para una categoría.
  static Map<String, Color> getStyle(String category) {
    final key = category.trim().toUpperCase();
    if (_styles.containsKey(key)) {
      return _styles[key]!;
    }
    if (key.contains('F')) return _fallbackF;
    if (key.contains('V')) return _fallbackV;
    return _fallbackDefault;
  }

  /// Compatibilidad con código existente (`bg` / `text`).
  static Map<String, Color> getColors(String category) {
    final style = getStyle(category);
    return {
      ...style,
      'bg': style['base']!,
      'text': style['onBase']!,
    };
  }

  /// Tokens resueltos para tiras y etiqueta de categoría en cards oscuras.
  ///
  /// - [label]: texto de categoría sobre fondo `#141C2E`
  /// - [verticalFill] / [verticalGlow]: tira vertical (ancla)
  /// - [horizontalFill] / [horizontalGlow]: tira bajo el nombre (refuerzo)
  static Map<String, Color> uiForDarkCard(String category) {
    final style = getStyle(category);
    final base = style['base']!;
    final onDark = style['onDark']!;
    final support = style['support']!;

    // Bases muy oscuras (ej. MV) no contrastan en el panel; usar onDark.
    final verticalFill =
        base.computeLuminance() < 0.10 ? onDark : base;

    return {
      'label': onDark,
      'verticalFill': verticalFill,
      'verticalGlow': onDark,
      'horizontalFill': support,
      'horizontalGlow': onDark,
    };
  }

  /// Primer token del nombre (ej. «U14 Femenil» → «U14»).
  static String shortName(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) return 'TBD';
    return trimmed.split(RegExp(r'\s+')).first.toUpperCase();
  }

  /// Etiqueta de categoría con color de paleta y tira horizontal (cards oscuras).
  static Widget buildDarkCardLabel(
    String category, {
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w800,
    TextAlign textAlign = TextAlign.start,
    bool showStrip = true,
    String? fallbackLabel,
  }) {
    final catUi = uiForDarkCard(category);
    final display = fallbackLabel ?? shortName(category);

    CrossAxisAlignment crossAlign;
    switch (textAlign) {
      case TextAlign.center:
        crossAlign = CrossAxisAlignment.center;
        break;
      case TextAlign.right:
      case TextAlign.end:
        crossAlign = CrossAxisAlignment.end;
        break;
      default:
        crossAlign = CrossAxisAlignment.start;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAlign,
      children: [
        Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
          style: GoogleFonts.oswald(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: catUi['label']!,
            height: 1,
            letterSpacing: 0.5,
          ),
        ),
        if (showStrip) ...[
          const SizedBox(height: 3),
          Container(
            width: fontSize * 1.4,
            height: 2,
            decoration: BoxDecoration(
              color: catUi['horizontalFill']!.withOpacity(0.8),
              borderRadius: BorderRadius.circular(1),
              boxShadow: [
                BoxShadow(
                  color: catUi['horizontalGlow']!.withOpacity(0.2),
                  blurRadius: 7,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
