import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Podfile に TensorFlowLite の Pod が追加されている', () async {
    const path = 'ios/Podfile';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path が存在すること');

    final podfile = await file.readAsString();
    // TensorFlowLiteSwift もしくは TensorFlowLite のどちらかが含まれることを許容
    final hasPod = podfile.contains("pod 'TensorFlowLiteSwift'") ||
        podfile.contains("pod 'TensorFlowLite'");
    expect(
      hasPod,
      isTrue,
      reason: "Podfile に pod 'TensorFlowLiteSwift' を追加してください",
    );
  });
}

