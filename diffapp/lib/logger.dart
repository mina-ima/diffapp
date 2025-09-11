import 'package:flutter/foundation.dart';

abstract class ErrorLogger {
  void record(Object error, StackTrace stack, {String tag});
}

class PrintErrorLogger implements ErrorLogger {
  @override
  void record(Object error, StackTrace stack, {String tag = 'app'}) {
    // 簡易実装: デバッグ出力に書き出す（将来ファイル保存に拡張可）
    debugPrint('[$tag] $error');
    debugPrint(stack.toString());
  }
}

class AppLog {
  static ErrorLogger instance = PrintErrorLogger();
}
