import 'package:diffapp/image_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyAutoContrastIfEnabled', () {
    test('disabled: 入力配列をそのまま返す', () {
      final input = [10, 20, 30, 40, 50];
      final out = applyAutoContrastIfEnabled(input, enabled: false);
      expect(out, equals(input));
      expect(identical(out, input), isFalse, reason: '新しい配列を返す（不変性）');
    });

    test('enabled: 0..255に線形正規化（min→0, max→255）', () {
      final input = [10, 20, 30, 40, 50];
      final out = applyAutoContrastIfEnabled(input, enabled: true);
      // min=10, max=50 → 幅40。30は ((30-10)*255)/40 = 127.5 ≈ 128
      expect(out.first, 0);
      expect(out.last, 255);
      expect(out[2], 128);
    });

    test('enabled: 全要素が同値の場合は変更しない', () {
      final input = List.filled(5, 128);
      final out = applyAutoContrastIfEnabled(input, enabled: true);
      expect(out, equals(input));
    });

    test('範囲外値（<0 or >255）はエラー', () {
      expect(() => applyAutoContrastIfEnabled([-1, 0, 1], enabled: true),
          throwsArgumentError);
      expect(() => applyAutoContrastIfEnabled([0, 256], enabled: true),
          throwsArgumentError);
    });
  });
}
