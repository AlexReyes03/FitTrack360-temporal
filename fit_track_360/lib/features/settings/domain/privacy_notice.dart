/// Versión del aviso que aceptan esta app y el DTO del API.
const supportedPrivacyNoticeVersion = '2';

const _monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String formatPrivacyNoticeDate(DateTime date) =>
    '${date.day} de ${_monthNames[date.month - 1]} de ${date.year}';

class PrivacyNoticeSection {
  const PrivacyNoticeSection({required this.title, required this.text});

  final String title;
  final String text;

  factory PrivacyNoticeSection.fromJson(Map<String, dynamic> json) =>
      PrivacyNoticeSection(
        title: json['title'] as String,
        text: json['text'] as String,
      );
}

class PrivacyNotice {
  const PrivacyNotice({
    required this.version,
    required this.date,
    required this.sections,
  });

  final String version;
  final DateTime date;
  final List<PrivacyNoticeSection> sections;

  bool get isEmpty => sections.isEmpty;

  bool get includesMedicalLimit =>
      sections.any((section) => section.title.toLowerCase().contains('salud'));

  factory PrivacyNotice.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (date == null) {
      throw const FormatException('Fecha del aviso inválida');
    }
    return PrivacyNotice(
      version: json['version'] as String? ?? '',
      date: date,
      sections: (json['sections'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                PrivacyNoticeSection.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }
}
