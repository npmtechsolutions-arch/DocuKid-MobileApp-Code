// SPIKE T9.0 — throwaway debug screen (RELEASE_V1_2 §9). Not part of the app:
// run it as its own target, debug builds only:
//   flutter run -t lib/debug/spike_t90_main.dart -d <emulator>
// Each button prints one `SPIKE <check> {...}` line (counts/timings/codes only).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _native = MethodChannel('docukit/native');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) throw StateError('Spike screens are debug-only.');
  runApp(const MaterialApp(home: _SpikeScreen()));
}

class _SpikeScreen extends StatefulWidget {
  const _SpikeScreen();

  @override
  State<_SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<_SpikeScreen> {
  final _out = <String>[];
  bool _busy = false;

  Future<Map<String, Object?>> _availability() async =>
      Map<String, Object?>.from(await _native.invokeMethod<Map<Object?, Object?>>('spikeScanAvailability') ?? {});

  Future<Map<String, Object?>> _scan() async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'spike_t90', '${DateTime.now().millisecondsSinceEpoch}'));
    final r = Map<String, Object?>.from(
        await _native.invokeMethod<Map<Object?, Object?>>('spikeScan', {'destDir': dir.path, 'pageLimit': 5}) ?? {});
    if (dir.existsSync()) {
      // Check the copies are real JPEGs (SOI marker) and that they're ours to delete.
      final files = dir.listSync().whereType<File>().toList();
      r['jpegOk'] = files.every((f) {
        final b = f.openSync()..setPositionSync(0);
        final head = b.readSync(2);
        b.closeSync();
        return head.length == 2 && head[0] == 0xFF && head[1] == 0xD8;
      });
      r['filesInDir'] = files.length;
      dir.deleteSync(recursive: true);
    }
    return r;
  }

  Future<void> _run(String name, Future<Map<String, Object?>> Function() check) async {
    setState(() => _busy = true);
    String line;
    try {
      line = 'SPIKE $name ${jsonEncode(await check())}';
    } catch (e) {
      line = 'SPIKE $name {"error":"${e.runtimeType}"}';
    }
    debugPrint(line);
    if (mounted) {
      setState(() {
        _out.insert(0, line);
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spike T9.0')),
      body: Column(children: [
        Wrap(spacing: 8, children: [
          ElevatedButton(
              key: const ValueKey('spike-avail'),
              onPressed: _busy ? null : () => _run('avail', _availability),
              child: const Text('availability')),
          ElevatedButton(
              key: const ValueKey('spike-install'),
              onPressed: _busy
                  ? null
                  : () => _run('install',
                      () async => Map<String, Object?>.from(await _native.invokeMethod<Map<Object?, Object?>>('spikeScanInstall') ?? {})),
              child: const Text('install')),
          ElevatedButton(
              key: const ValueKey('spike-scan'),
              onPressed: _busy ? null : () => _run('scan', _scan),
              child: const Text('scan')),
        ]),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: ListView(children: [for (final l in _out) SelectableText(l)])),
      ]),
    );
  }
}
