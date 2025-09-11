import 'package:flutter/material.dart';
import 'package:diffapp/settings.dart';

class SettingsPage extends StatefulWidget {
  final Settings initial;

  const SettingsPage({super.key, required this.initial});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Settings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial;
  }

  void _update({
    bool? color,
    bool? shape,
    bool? position,
    bool? size,
    bool? text,
    bool? sound,
    int? precision,
  }) {
    setState(() {
      _settings = _settings.copyWith(
        detectColor: color,
        detectShape: shape,
        detectPosition: position,
        detectSize: size,
        detectText: text,
        enableSound: sound,
        precision: precision,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: () => Navigator.of(context).pop(_settings),
          ),
        ],
      ),
      body: ListView(
        children: [
          const _SectionTitle('検出項目'),
          CheckboxListTile(
            title: const Text('色'),
            value: _settings.detectColor,
            onChanged: (bool? v) => _update(color: v ?? _settings.detectColor),
          ),
          CheckboxListTile(
            title: const Text('形'),
            value: _settings.detectShape,
            onChanged: (bool? v) => _update(shape: v ?? _settings.detectShape),
          ),
          CheckboxListTile(
            title: const Text('場所'),
            value: _settings.detectPosition,
            onChanged: (bool? v) =>
                _update(position: v ?? _settings.detectPosition),
          ),
          CheckboxListTile(
            title: const Text('大きさ'),
            value: _settings.detectSize,
            onChanged: (bool? v) => _update(size: v ?? _settings.detectSize),
          ),
          CheckboxListTile(
            title: const Text('文字'),
            value: _settings.detectText,
            onChanged: (bool? v) => _update(text: v ?? _settings.detectText),
          ),
          const Divider(height: 24),
          const _SectionTitle('その他'),
          CheckboxListTile(
            title: const Text('効果音'),
            value: _settings.enableSound,
            onChanged: (bool? v) => _update(sound: v ?? _settings.enableSound),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('OSS ライセンス'),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Diffapp',
            ),
          ),
          const Divider(height: 24),
          const _SectionTitle('精度'),
          ListTile(
            title: Row(
              children: [
                const Text('低'),
                Expanded(
                  child: Slider(
                    value: _settings.precision.toDouble(),
                    min: Settings.minPrecision.toDouble(),
                    max: Settings.maxPrecision.toDouble(),
                    divisions: Settings.maxPrecision - Settings.minPrecision,
                    label: _settings.precision.toString(),
                    onChanged: (double v) => _update(precision: v.round()),
                  ),
                ),
                const Text('高'),
              ],
            ),
            subtitle: Text('現在: ${_settings.precision}'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
