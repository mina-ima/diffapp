import 'dart:convert';

class Settings {
  static const int minPrecision = 1;
  static const int maxPrecision = 5;
  static const int defaultPrecision = 3; // 「普通精度」
  static const int defaultMinAreaPercent = 5; // 検出の最小面積（解析空間比）

  final bool detectColor;
  final bool detectShape;
  final bool detectPosition;
  final bool detectSize;
  final bool detectText;
  final bool enableSound;
  final int precision; // 1..5
  final int minAreaPercent; // 0..100 (% of analysis area)

  const Settings({
    required this.detectColor,
    required this.detectShape,
    required this.detectPosition,
    required this.detectSize,
    required this.detectText,
    required this.enableSound,
    required this.precision,
    required this.minAreaPercent,
  })  : assert(
          precision >= minPrecision && precision <= maxPrecision,
          'precision must be within $minPrecision..$maxPrecision',
        ),
        assert(
          minAreaPercent >= 0 && minAreaPercent <= 100,
          'minAreaPercent must be within 0..100',
        );

  factory Settings.initial() => const Settings(
        detectColor: true,
        detectShape: true,
        detectPosition: true,
        detectSize: true,
        detectText: true,
        enableSound: true,
        precision: defaultPrecision,
        minAreaPercent: defaultMinAreaPercent,
      );

  Settings copyWith({
    bool? detectColor,
    bool? detectShape,
    bool? detectPosition,
    bool? detectSize,
    bool? detectText,
    bool? enableSound,
    int? precision,
    int? minAreaPercent,
  }) {
    final nextPrecision = precision ?? this.precision;
    if (nextPrecision < minPrecision || nextPrecision > maxPrecision) {
      throw ArgumentError(
        'precision must be within $minPrecision..$maxPrecision',
      );
    }
    final nextMinArea = minAreaPercent ?? this.minAreaPercent;
    if (nextMinArea < 0 || nextMinArea > 100) {
      throw ArgumentError('minAreaPercent must be within 0..100');
    }
    return Settings(
      detectColor: detectColor ?? this.detectColor,
      detectShape: detectShape ?? this.detectShape,
      detectPosition: detectPosition ?? this.detectPosition,
      detectSize: detectSize ?? this.detectSize,
      detectText: detectText ?? this.detectText,
      enableSound: enableSound ?? this.enableSound,
      precision: nextPrecision,
      minAreaPercent: nextMinArea,
    );
  }

  Map<String, dynamic> toMap() => {
        'detectColor': detectColor,
        'detectShape': detectShape,
        'detectPosition': detectPosition,
        'detectSize': detectSize,
        'detectText': detectText,
        'enableSound': enableSound,
        'precision': precision,
        'minAreaPercent': minAreaPercent,
      };

  String toJson() => jsonEncode(toMap());

  factory Settings.fromMap(Map<String, dynamic> map) {
    // Start with defaults, override with provided keys.
    final base = Settings.initial();
    final int nextPrecision = (map['precision'] ?? base.precision) as int;
    if (nextPrecision < minPrecision || nextPrecision > maxPrecision) {
      throw ArgumentError(
        'precision must be within $minPrecision..$maxPrecision',
      );
    }
    final int nextMinArea = (map['minAreaPercent'] ?? base.minAreaPercent) as int;
    if (nextMinArea < 0 || nextMinArea > 100) {
      throw ArgumentError('minAreaPercent must be within 0..100');
    }
    bool readBool(String key, bool def) {
      final v = map[key];
      if (v == null) return def;
      if (v is bool) return v;
      throw FormatException('Expected bool for "$key"');
    }

    return Settings(
      detectColor: readBool('detectColor', base.detectColor),
      detectShape: readBool('detectShape', base.detectShape),
      detectPosition: readBool('detectPosition', base.detectPosition),
      detectSize: readBool('detectSize', base.detectSize),
      detectText: readBool('detectText', base.detectText),
      enableSound: readBool('enableSound', base.enableSound),
      precision: nextPrecision,
      minAreaPercent: nextMinArea,
    );
  }

  factory Settings.fromJson(String source) {
    final map = jsonDecode(source);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('Invalid JSON for Settings');
    }
    return Settings.fromMap(map);
  }

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.detectColor == detectColor &&
      other.detectShape == detectShape &&
      other.detectPosition == detectPosition &&
      other.detectSize == detectSize &&
      other.detectText == detectText &&
      other.enableSound == enableSound &&
      other.precision == precision &&
      other.minAreaPercent == minAreaPercent;

  @override
  int get hashCode => Object.hash(
        detectColor,
        detectShape,
        detectPosition,
        detectSize,
        detectText,
        enableSound,
        precision,
        minAreaPercent,
      );

  @override
  String toString() =>
      'Settings(color:$detectColor, shape:$detectShape, pos:$detectPosition, size:$detectSize, text:$detectText, sound:$enableSound, precision:$precision, minArea%:$minAreaPercent)';
}
