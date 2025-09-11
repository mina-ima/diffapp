import 'dart:convert';

class Settings {
  static const int minPrecision = 1;
  static const int maxPrecision = 5;
  static const int defaultPrecision = 3; // 「普通精度」

  final bool detectColor;
  final bool detectShape;
  final bool detectPosition;
  final bool detectSize;
  final bool detectText;
  final int precision; // 1..5

  const Settings({
    required this.detectColor,
    required this.detectShape,
    required this.detectPosition,
    required this.detectSize,
    required this.detectText,
    required this.precision,
  }) : assert(precision >= minPrecision && precision <= maxPrecision,
            'precision must be within $minPrecision..$maxPrecision');

  factory Settings.initial() => const Settings(
        detectColor: true,
        detectShape: true,
        detectPosition: true,
        detectSize: true,
        detectText: true,
        precision: defaultPrecision,
      );

  Settings copyWith({
    bool? detectColor,
    bool? detectShape,
    bool? detectPosition,
    bool? detectSize,
    bool? detectText,
    int? precision,
  }) {
    final nextPrecision = precision ?? this.precision;
    if (nextPrecision < minPrecision || nextPrecision > maxPrecision) {
      throw ArgumentError('precision must be within $minPrecision..$maxPrecision');
    }
    return Settings(
      detectColor: detectColor ?? this.detectColor,
      detectShape: detectShape ?? this.detectShape,
      detectPosition: detectPosition ?? this.detectPosition,
      detectSize: detectSize ?? this.detectSize,
      detectText: detectText ?? this.detectText,
      precision: nextPrecision,
    );
  }

  Map<String, dynamic> toMap() => {
        'detectColor': detectColor,
        'detectShape': detectShape,
        'detectPosition': detectPosition,
        'detectSize': detectSize,
        'detectText': detectText,
        'precision': precision,
      };

  String toJson() => jsonEncode(toMap());

  factory Settings.fromMap(Map<String, dynamic> map) {
    // Start with defaults, override with provided keys.
    final base = Settings.initial();
    final int nextPrecision = (map['precision'] ?? base.precision) as int;
    if (nextPrecision < minPrecision || nextPrecision > maxPrecision) {
      throw ArgumentError('precision must be within $minPrecision..$maxPrecision');
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
      precision: nextPrecision,
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
      other.precision == precision;

  @override
  int get hashCode => Object.hash(
        detectColor,
        detectShape,
        detectPosition,
        detectSize,
        detectText,
        precision,
      );

  @override
  String toString() =>
      'Settings(color:$detectColor, shape:$detectShape, pos:$detectPosition, size:$detectSize, text:$detectText, precision:$precision)';
}

