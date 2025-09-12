import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text(
            '本アプリは完全オフラインで動作し、画像や個人情報を外部に送信しません。',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 12),
          Text('1. 収集する情報'),
          Text('アプリ内で処理する画像データは端末内でのみ利用し、サーバへ送信しません。'),
          SizedBox(height: 8),
          Text('2. 利用目的'),
          Text('画像の比較・検出処理および結果表示のみを目的に端末内で利用します。'),
          SizedBox(height: 8),
          Text('3. 第三者提供'),
          Text('第三者への提供は一切行いません。'),
          SizedBox(height: 8),
          Text('4. 端末権限'),
          Text('カメラ・写真ライブラリの権限は画像入力目的でのみ使用します。'),
          SizedBox(height: 8),
          Text('5. お問い合わせ'),
          Text('ご不明点はアプリ配布ページ記載の連絡先へお問い合わせください。'),
        ],
      ),
    );
  }
}

