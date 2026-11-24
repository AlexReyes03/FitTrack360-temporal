/// Escala de espaciado del design system (dp).
///
/// Escala base: hairline 2 · xxs 4 · xs 8 · sm 12 · base 16 · md 24 · lg 32.
class AppSpacing {
  AppSpacing._();

  /// Separación mínima (p. ej. entre título y subtítulo pegados).
  static const double hairline = 2;

  /// Separación entre etiqueta y valor o icono y texto.
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;

  /// Paso intermedio: separación entre tarjetas y padding compacto.
  static const double base = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double contentMaxWidth = 760;

  /// Padding interior de toda tarjeta glass (Inicio, Progreso, Comidas,
  /// Perfil). Igual al padding por defecto de GlassSurface.
  static const double cardPadding = md;

  /// Separación vertical entre tarjetas/secciones de una pantalla.
  static const double sectionGap = base;
}
