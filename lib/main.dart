// Oversight verifier — mobile UI.
//
// v0.1: open a `.oversight` bundle, verify it offline, show the result.
// No network, no telemetry, no accounts. Verification is one FFI hop into the
// Rust core that powers the desktop CLI — bit-identical answer.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'src/rust/api/verify.dart';
import 'src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const OversightApp());
}

class OversightApp extends StatelessWidget {
  const OversightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oversight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F6FEB),
          brightness: Brightness.dark,
        ),
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
  String _libVersion = '…';
  VerifyResult? _result;
  String? _resultFilename;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final v = await libraryVersion();
      if (mounted) setState(() => _libVersion = v);
    } catch (e) {
      if (mounted) setState(() => _libVersion = 'native lib failed: $e');
    }
  }

  Future<void> _pickAndVerify() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _resultFilename = null;
    });
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Pick an .oversight bundle',
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final file = picked.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        throw 'could not read picked file';
      }
      final r = await verifyBundle(bundleBytes: bytes);
      if (!mounted) return;
      setState(() {
        _result = r;
        _resultFilename = file.name;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oversight'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => _showAbout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Tagline(),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.lock_open),
                label: const Text('Verify a bundle'),
                onPressed: _busy ? null : _pickAndVerify,
              ),
              const SizedBox(height: 16),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null) _ErrorCard(message: _error!),
              if (_result != null)
                Expanded(
                  child: _ResultView(
                    filename: _resultFilename ?? '(unknown)',
                    result: _result!,
                  ),
                ),
              if (_result == null && !_busy && _error == null) const Spacer(),
              Center(
                child: Text(
                  'oversight-core $_libVersion · offline · zero telemetry',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Oversight',
      applicationVersion: 'verifier · core $_libVersion',
      applicationLegalese:
          'Apache 2.0 · github.com/oversight-protocol\n\n'
          'Verifies Oversight-attested bundles entirely offline. No data '
          'leaves your device. Verification is bit-identical to the desktop '
          'CLI — same Rust core, same answer.',
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verify a sealed document', style: t.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Cryptographic proof, in your pocket. Offline.',
          style: t.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white))),
        ]),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final String filename;
  final VerifyResult result;
  const _ResultView({required this.filename, required this.result});

  @override
  Widget build(BuildContext context) {
    final ok = result.status == VerifyStatus.ok;
    final color = ok ? Colors.green : Colors.red;
    final title = ok ? 'VERIFIED' : 'NOT VERIFIED';
    final m = result.manifest;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm UTC');
    final issuedAt = m.issuedAtUnix > 0
        ? dateFmt.format(DateTime.fromMillisecondsSinceEpoch(
            m.issuedAtUnix.toInt() * 1000,
            isUtc: true))
        : '(no timestamp)';

    return ListView(
      children: [
        Card(
          color: color.withAlpha(38),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: color, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(ok ? Icons.verified : Icons.gpp_bad, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: color,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text(filename,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ]),
          ),
        ),
        if (result.failures.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.red.shade900,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Failure reasons',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...result.failures.map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $f'),
                      )),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _kv('Issuer', m.issuerId.isEmpty ? '(unset)' : m.issuerId),
        _kv('Issuer pubkey',
            m.issuerPubkeyShort.isEmpty ? '(unset)' : m.issuerPubkeyShort),
        _kv('Original filename', m.originalFilename),
        _kv('Content type', m.contentType),
        _kv('Content hash', m.contentHashShort),
        _kv('Size', '${m.sizeBytes} bytes'),
        _kv('Issued at', issuedAt),
        _kv('Suite', m.suite),
        _kv('Watermarks', '${m.watermarkCount}'),
        _kv('Has recipient', m.hasRecipient ? 'yes' : 'no'),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Bundle: ${result.bundleSizeBytes} bytes · verified locally · no network used',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: const TextStyle(color: Colors.white60)),
          ),
          Expanded(child: SelectableText(v)),
        ],
      ),
    );
  }
}
