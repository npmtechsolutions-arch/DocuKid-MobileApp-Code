// SPIKE T8.0 — throwaway debug screen (RELEASE_V1_1 §9). Not part of the app:
// run it as its own target, debug or profile builds only:
//   flutter run -t lib/debug/spike_t80_main.dart -d <emulator> [--profile]
// Each button prints one `SPIKE <check> {...}` line (timings/flags only).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'spike_t80.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Debug or --profile (for timings); never release.
  if (kReleaseMode) throw StateError('Spike screens are never built for release.');
  await pdfrxFlutterInitialize();
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

  Future<void> _run(String name, Future<Map<String, Object?>> Function(Directory) check) async {
    setState(() => _busy = true);
    final work = Directory(p.join((await getTemporaryDirectory()).path, 'spike_t80', name));
    String line;
    try {
      line = 'SPIKE $name ${jsonEncode(await check(work))}';
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
    final checks = <(String, Future<Map<String, Object?>> Function(Directory))>[
      ('zip', spikeZip),
      ('encode', spikeEncodeFormats),
      ('p2i', spikeP2i),
      ('saf', (d) => spikeSaveMany(d, sizeMb: 3)),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Spike T8.0')),
      body: Column(children: [
        Wrap(spacing: 8, children: [
          for (final (name, check) in checks)
            ElevatedButton(
              key: ValueKey('spike-$name'),
              onPressed: _busy ? null : () => _run(name, check),
              child: Text(name),
            ),
        ]),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: ListView(children: [for (final l in _out) SelectableText(l)])),
      ]),
    );
  }
}
