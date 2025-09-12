import 'dart:convert';
import 'dart:io';

class SdkCompatResult {
  final bool ok;
  final String message;
  const SdkCompatResult(this.ok, this.message);

  @override
  String toString() => 'SdkCompatResult(ok: $ok, message: $message)';
}

class SemVer implements Comparable<SemVer> {
  final int major;
  final int minor;
  final int patch;

  const SemVer(this.major, this.minor, this.patch);

  static SemVer parse(String input) {
    final parts = input.trim().split('.');
    if (parts.length < 3) {
      throw FormatException('Invalid semver: $input');
    }
    int parseInt(String s) =>
        int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return SemVer(parseInt(parts[0]), parseInt(parts[1]), parseInt(parts[2]));
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// Evaluate a version string against a simple space-separated range like
/// ">=3.4.0 <4.0.0". Supports ">=", ">", "<=", "<", "=="/"=".
bool satisfiesConstraint(String versionStr, String constraintStr) {
  final v = SemVer.parse(versionStr);
  // オペレータとバージョンの間の空白を許容する。
  final re = RegExp(r'(>=|>|<=|<|==|=)\s*([0-9]+\.[0-9]+\.[0-9]+)');
  final matches = re.allMatches(constraintStr);
  for (final m in matches) {
    final op = m.group(1)!;
    final rhs = SemVer.parse(m.group(2)!);
    final cmp = v.compareTo(rhs);
    switch (op) {
      case '>':
        if (!(cmp > 0)) return false;
        break;
      case '>=':
        if (!(cmp >= 0)) return false;
        break;
      case '<':
        if (!(cmp < 0)) return false;
        break;
      case '<=':
        if (!(cmp <= 0)) return false;
        break;
      case '==':
      case '=':
        if (cmp != 0) return false;
        break;
    }
  }
  // マッチが1つも無い場合は、制約の解釈に失敗したとみなし、保守的に false を返す。
  return matches.isNotEmpty;
}

String? _extractSdkConstraintFromPubspec(String yaml) {
  // よりロバストに sdk: 行から値を抽出（単/二重引用・無引用・行末コメント対応）
  final m = RegExp(r'^\s*sdk\s*:\s*(.+)$', multiLine: true).firstMatch(yaml);
  if (m == null) return null;
  var val = m.group(1)!.trim();
  // 行末コメントを除去
  final hash = val.indexOf('#');
  if (hash >= 0) {
    val = val.substring(0, hash).trim();
  }
  if (val.isEmpty) return null;
  // 引用除去（対応する始終の ' または " のみ）
  if ((val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))) {
    val = val.substring(1, val.length - 1);
  }
  return val.trim();
}

// テスト用のパブリックAPI（内部実装をそのまま公開）
String? extractSdkConstraintFromPubspec(String yaml) =>
    _extractSdkConstraintFromPubspec(yaml);

String? _dartVersionForFlutter(String flutterVersion) {
  // Minimal mapping for our pinned version. Extend if bumping Flutter.
  const map = {
    '3.22.0': '3.4.0',
    // If needed in future:
    // '3.22.1': '3.4.1',
    // '3.22.2': '3.4.2',
    // '3.22.3': '3.4.3',
  };
  if (map.containsKey(flutterVersion)) return map[flutterVersion];
  // Loose fallback for 3.22.x → 3.4.x (best-effort when patch differs)
  final m = RegExp(r'^(3)\.(22)\.(\d+)$').firstMatch(flutterVersion);
  if (m != null) {
    final patch = int.tryParse(m.group(3) ?? '0') ?? 0;
    return '3.4.$patch';
  }
  return null; // unknown mapping
}

Future<SdkCompatResult> checkCompatibilityFromFiles({
  required String pubspecPath,
  required String fvmConfigPath,
}) async {
  final pubspec = await File(pubspecPath).readAsString();
  final sdkConstraint = _extractSdkConstraintFromPubspec(pubspec);
  if (sdkConstraint == null) {
    return const SdkCompatResult(false, 'pubspec.yaml の sdk 範囲が見つかりません');
  }

  final cfg = jsonDecode(await File(fvmConfigPath).readAsString())
      as Map<String, dynamic>;
  final flutterVersion = cfg['flutterSdkVersion']?.toString();
  if (flutterVersion == null || flutterVersion.isEmpty) {
    return const SdkCompatResult(
        false, 'fvm_config.json の flutterSdkVersion が不明');
  }

  final dartVersion = _dartVersionForFlutter(flutterVersion);
  if (dartVersion == null) {
    return SdkCompatResult(false, '未対応の Flutter 版です: $flutterVersion');
  }

  final ok = satisfiesConstraint(dartVersion, sdkConstraint);
  final msg = ok
      ? '互換 OK: Flutter $flutterVersion (Dart $dartVersion) は pubspec の "$sdkConstraint" を満たします'
      : '互換 NG: Flutter $flutterVersion (Dart $dartVersion) は pubspec の "$sdkConstraint" を満たしません';
  return SdkCompatResult(ok, msg);
}
