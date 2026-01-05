library server_setup_screen;

import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';
import '../../core/api/api_client.dart';

class ServerSetupScreen extends StatefulWidget {
  const ServerSetupScreen({super.key});
  @override
  State<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends State<ServerSetupScreen> {
  late final TextEditingController _c;
  bool _busy = false;
  bool _writeBesideExe = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: AppConfig.defaultBaseUrl);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    setState(() { _busy = true; _status = 'Testing /api/health'; });
    final url = AppConfig.normalize(_c.text);
    final ok = await ApiClient(url).healthCheck();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _busy = false;
        _status = 'No response. Use A/B or enter http://<LAN-IP>:3001';
      });
      return;
    }

    await AppConfig.save(url, besideExe: _writeBesideExe);
    if (!mounted) return;
    setState(() { _busy = false; _status = 'Saved. Restart app.'; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Backend URL (reachable on LAN):'),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              decoration: const InputDecoration(
                labelText: 'serverBaseUrl',
                hintText: 'http://<LAN-IP>:3001',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _c.text = AppConfig.defaultBaseUrl),
                  child: const Text('A: simon-physio.local'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _c.text = AppConfig.optionHostnameStandard),
                  child: const Text('B: physio-server'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _c.text = 'http://<LAN-IP>:3001'),
                  child: const Text('C: LAN-IP'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _writeBesideExe,
              onChanged: _busy ? null : (v) => setState(() => _writeBesideExe = v),
              title: const Text('Also write config.json beside EXE'),
              subtitle: const Text('Enterprise deploy (USB/Share).'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _busy ? null : _testAndSave,
              child: Text(_busy ? 'Working' : 'Test + Save'),
            ),
            const SizedBox(height: 10),
            Text(_status),
          ],
        ),
      ),
    );
  }
}