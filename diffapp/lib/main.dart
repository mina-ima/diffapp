import 'package:flutter/material.dart';
import 'package:diffapp/settings.dart';
import 'package:diffapp/screens/settings_page.dart';
import 'package:diffapp/screens/image_select_page.dart';
import 'package:diffapp/screens/compare_page.dart';

void main() {
  runApp(const DiffApp());
}

class DiffApp extends StatelessWidget {
  const DiffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diffapp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Settings _settings = Settings.initial();
  SelectedImage? _leftImage;
  SelectedImage? _rightImage;

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<Settings>(
      MaterialPageRoute(builder: (_) => SettingsPage(initial: _settings)),
    );
    if (result != null) {
      setState(() => _settings = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diffapp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  // 簡易ロゴ（将来画像に置換可）
                  const FlutterLogo(key: Key('app-logo'), size: 72),
                  const SizedBox(height: 8),
                  Text(
                    'AIがちがいをみつけるよ',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('画像をえらんでね', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _imageCard(
                      side: '左',
                      value: _leftImage,
                      onPick: () => _pick('left'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imageCard(
                      side: '右',
                      value: _rightImage,
                      onPick: () => _pick('right'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('けんさをはじめる'),
            ),
            const SizedBox(height: 8),
            Text(
              '現在の設定: 精度${_settings.precision} / 色:${_settings.detectColor} 形:${_settings.detectShape} 場所:${_settings.detectPosition} 大きさ:${_settings.detectSize} 文字:${_settings.detectText} 音:${_settings.enableSound}',
            ),
          ],
        ),
      ),
    );
  }

  void _onStart() {
    if (_leftImage == null || _rightImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('がぞうを えらんでね')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComparePage(
          left: _leftImage!,
          right: _rightImage!,
          enableSound: _settings.enableSound,
        ),
      ),
    );
  }

  Widget _imageCard({
    required String side,
    required SelectedImage? value,
    required VoidCallback onPick,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 64, color: Colors.grey),
            const SizedBox(height: 8),
            Text('$side 画像: ${value?.label ?? '未選択'}'),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onPick, child: Text('$side の画像を選ぶ')),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(String side) async {
    final title = side == 'left' ? '左の画像を選ぶ' : '右の画像を選ぶ';
    final result = await Navigator.of(context).push<SelectedImage>(
      MaterialPageRoute(builder: (_) => ImageSelectPage(title: title)),
    );
    if (result != null) {
      setState(() {
        if (side == 'left') {
          _leftImage = result;
        } else {
          _rightImage = result;
        }
      });
    }
  }
}
