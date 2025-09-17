import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  final bool noDifferences;
  const ResultPage({super.key, this.noDifferences = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('検査結果')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noDifferences)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('ちがいは みつかりませんでした'),
              ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'スクショをとろう！',
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('再比較'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

