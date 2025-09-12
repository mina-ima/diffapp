import 'package:flutter/material.dart';

class OssLicensesPage extends StatelessWidget {
  const OssLicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Material の LicensePage をそのまま使用するが、
    // ルート型を独自ページ(OssLicensesPage)として提供する。
    return const LicensePage(
      applicationName: 'Diffapp',
    );
  }
}

