// Oversight verifier — mobile UI.
//
// v0.1.3: verifier-only app for iOS + Android. Single FFI hop into the
// Oversight Rust core (bit-identical with the desktop CLI). No network,
// no telemetry, no accounts.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/rust/api/verify.dart';
import 'src/rust/frb_generated.dart';

const _githubUrl = 'https://github.com/oversight-protocol/oversight';
const _onboardingDoneKey = 'onboarding_done_v1';
const _historyKey = 'verify_history_v1';
const _historyMax = 20;
const _bundleExtensions = ['oversight', 'sealed'];

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
      home: const _Boot(),
    );
  }
}

class _Boot extends StatefulWidget {
  const _Boot();
  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_onboardingDoneKey) ?? false;
    if (mounted) setState(() => _showOnboarding = !done);
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_showOnboarding!) {
      return _Onboarding(onDone: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_onboardingDoneKey, true);
        if (mounted) setState(() => _showOnboarding = false);
      });
    }
    return const HomePage();
  }
}

// ---------------------------------------------------------------- Onboarding

class _Onboarding extends StatefulWidget {
  final VoidCallback onDone;
  const _Onboarding({required this.onDone});
  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final _ctrl = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPage(
      icon: Icons.shield_outlined,
      title: 'What Oversight does',
      body:
          'Oversight verifies that a sealed file (.oversight or .sealed) was '
          'signed by a specific person and has not been altered. The check '
          'happens on this device. Nothing is uploaded.',
    ),
    _OnboardPage(
      icon: Icons.inbox_outlined,
      title: 'Where bundles come from',
      body:
          'Someone seals a file with the Oversight desktop CLI, then sends '
          'you the .oversight bundle (email, AirDrop, Messages, anywhere). '
          'You open it with this app to verify it.',
    ),
    _OnboardPage(
      icon: Icons.lock_outline,
      title: 'What stays on this device',
      body:
          'Every byte. Oversight does not phone home, no telemetry, no '
          'accounts, no servers. Verification is bit-identical to the '
          'desktop CLI — same Rust core, same answer.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: _pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onDone,
                    child: const Text('Skip'),
                  ),
                  Row(
                    children: List.generate(
                      _pages.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (last) {
                        widget.onDone();
                      } else {
                        _ctrl.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(last ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _OnboardPage(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 32),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- Home

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _libVersion = '…';
  bool _busy = false;
  String? _error;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadHistory();
  }

  Future<void> _loadVersion() async {
    try {
      final v = await libraryVersion();
      if (mounted) setState(() => _libVersion = v);
    } catch (e) {
      if (mounted) setState(() => _libVersion = 'native lib failed: $e');
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_historyKey) ?? [];
    final entries = raw
        .map((s) {
          try {
            return HistoryEntry.fromJson(jsonDecode(s));
          } catch (_) {
            return null;
          }
        })
        .whereType<HistoryEntry>()
        .toList();
    if (mounted) setState(() => _history = entries);
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _historyKey,
      _history.take(_historyMax).map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) setState(() => _history = []);
  }

  Future<void> _pickAndVerify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.pickFiles(
        dialogTitle: 'Pick an Oversight bundle',
        type: FileType.custom,
        allowedExtensions: _bundleExtensions,
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
      if (bytes == null) throw 'could not read picked file';
      await _verify(bytes, file.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _verifyAsset(String assetPath, String displayName) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await rootBundle.load(assetPath);
      await _verify(data.buffer.asUint8List(), displayName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _verify(Uint8List bytes, String fileName) async {
    final r = await verifyBundle(bundleBytes: bytes);
    if (!mounted) return;
    final entry = HistoryEntry.fromResult(fileName, r);
    setState(() {
      _history = [entry, ..._history.where((e) => e.id != entry.id)]
          .take(_historyMax)
          .toList();
      _busy = false;
    });
    await _saveHistory();
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultPage(filename: fileName, result: r),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oversight'),
        actions: [
          if (_history.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'clear') _confirmClearHistory();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Clear history'),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () => _showAbout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Tagline(),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('Verify a bundle'),
              onPressed: _busy ? null : _pickAndVerify,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: const Text('Try sample (valid)'),
                    onPressed: _busy
                        ? null
                        : () => _verifyAsset(
                              'assets/samples/sample_welcome.oversight',
                              'sample_welcome.oversight',
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.warning_amber_outlined, size: 18),
                    label: const Text('Try sample (tampered)'),
                    onPressed: _busy
                        ? null
                        : () => _verifyAsset(
                              'assets/samples/sample_tampered.oversight',
                              'sample_tampered.oversight',
                            ),
                  ),
                ),
              ],
            ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _error!),
            ],
            const SizedBox(height: 24),
            if (_history.isEmpty)
              const _EmptyHint()
            else ...[
              Text(
                'Recent verifications',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._history.map((h) => _HistoryTile(
                    entry: h,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ResultPage.fromHistory(h),
                    )),
                  )),
            ],
            const SizedBox(height: 24),
            Center(
              child: Text(
                'oversight-core $_libVersion · offline · zero telemetry',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
            'This removes the local list of past verifications. The bundles themselves are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearHistory();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Oversight'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('verifier · core $_libVersion'),
            const SizedBox(height: 12),
            const Text(
              'Apache 2.0 · open source\n\n'
              'Verifies Oversight-attested bundles entirely offline. No data '
              'leaves your device. Verification is bit-identical to the '
              'desktop CLI — same Rust core, same answer.',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => launchUrl(Uri.parse(_githubUrl),
                  mode: LaunchMode.externalApplication),
              child: Text(
                _githubUrl,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showLicensePage(context: context, applicationName: 'Oversight');
            },
            child: const Text('Licenses'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Components

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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.lightbulb_outline, size: 20),
              SizedBox(width: 8),
              Text('No verifications yet',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            SizedBox(height: 8),
            Text(
              'Tap "Try sample" above to see a valid and a tampered bundle. '
              'When someone shares a real Oversight bundle (.oversight or '
              '.sealed) with you, tapping it from email, AirDrop, or Messages '
              'should open this app directly.',
              style: TextStyle(color: Colors.white70, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;
  const _HistoryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ok = entry.ok;
    final color = ok ? Colors.green : Colors.red;
    final fmt = DateFormat('MMM d · HH:mm');
    return Card(
      child: ListTile(
        leading: Icon(ok ? Icons.verified : Icons.gpp_bad, color: color),
        title:
            Text(entry.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${ok ? "Verified" : "Not verified"} · ${fmt.format(DateTime.fromMillisecondsSinceEpoch(entry.atUnix * 1000))}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
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
              child: Text(message,
                  style: const TextStyle(color: Colors.white))),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ Result

class ResultPage extends StatelessWidget {
  final String filename;
  final VerifyResult result;
  const ResultPage({super.key, required this.filename, required this.result});

  factory ResultPage.fromHistory(HistoryEntry h) {
    return ResultPage(filename: h.filename, result: h.toVerifyResult());
  }

  bool get _ok => result.status == VerifyStatus.ok;

  String get _humanReason {
    if (_ok) return 'This file is sealed and intact.';
    if (result.failures.any((f) => f.toLowerCase().contains('signature'))) {
      return "This file's signature doesn't match. The file may have been altered, or the sender's key isn't recognized.";
    }
    if (result.failures.any((f) => f.toLowerCase().contains('parse'))) {
      return "This file isn't a valid Oversight bundle, or it's been corrupted.";
    }
    if (result.failures.any((f) => f.toLowerCase().contains('content_hash'))) {
      return "This bundle is missing required cryptographic fields.";
    }
    return 'Verification failed. See technical details below.';
  }

  String _receiptJson() {
    final m = result.manifest;
    final receipt = {
      'oversight_receipt': 'v1',
      'verified_at': DateTime.now().toUtc().toIso8601String(),
      'filename': filename,
      'status': _ok ? 'verified' : 'not_verified',
      'signature_valid': result.signatureValid,
      'failures': result.failures,
      'bundle_size_bytes': result.bundleSizeBytes.toInt(),
      'manifest': {
        'file_id': m.fileId,
        'issuer_id': m.issuerId,
        'issuer_pubkey_short': m.issuerPubkeyShort,
        'original_filename': m.originalFilename,
        'content_type': m.contentType,
        'content_hash_short': m.contentHashShort,
        'size_bytes': m.sizeBytes.toInt(),
        'issued_at_unix': m.issuedAtUnix.toInt(),
        'suite': m.suite,
        'watermark_count': m.watermarkCount.toInt(),
        'has_recipient': m.hasRecipient,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(receipt);
  }

  String _humanSummary() {
    final m = result.manifest;
    final fmt = DateFormat('yyyy-MM-dd HH:mm UTC');
    final issued = m.issuedAtUnix > 0
        ? fmt.format(DateTime.fromMillisecondsSinceEpoch(
            m.issuedAtUnix.toInt() * 1000,
            isUtc: true))
        : '(no timestamp)';
    final lines = [
      'Oversight verification receipt',
      '',
      'File:        $filename',
      'Status:      ${_ok ? "VERIFIED" : "NOT VERIFIED"}',
      'Issuer:      ${m.issuerId.isEmpty ? "(unset)" : m.issuerId}',
      'Issued at:   $issued',
      'Original:    ${m.originalFilename}',
      'Content:     ${m.contentType} · ${m.sizeBytes} bytes',
      'Hash:        ${m.contentHashShort}',
      'Bundle:      ${result.bundleSizeBytes} bytes',
      if (!_ok) ...[
        '',
        'Failure reasons:',
        ...result.failures.map((f) => '  - $f'),
      ],
      '',
      'Verified offline by Oversight (oversight-protocol.dev). No data left this device.',
    ];
    return lines.join('\n');
  }

  String _receiptText() {
    return '${_humanSummary()}\n\n--- JSON receipt ---\n${_receiptJson()}';
  }

  Future<void> _share(BuildContext context) async {
    await SharePlus.instance.share(ShareParams(
      title: 'Oversight verification — $filename',
      text: _receiptText(),
      subject: '${_ok ? "Verified" : "Not verified"}: $filename',
    ));
  }

  Future<void> _copyReceipt(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _receiptText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _ok ? Colors.green : Colors.red;
    final m = result.manifest;
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm UTC');
    final issuedAt = m.issuedAtUnix > 0
        ? dateFmt.format(DateTime.fromMillisecondsSinceEpoch(
            m.issuedAtUnix.toInt() * 1000,
            isUtc: true))
        : '(no timestamp)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy receipt',
            onPressed: () => _copyReceipt(context),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share receipt',
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
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
                  Icon(_ok ? Icons.verified : Icons.gpp_bad,
                      color: color, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_ok ? 'VERIFIED' : 'NOT VERIFIED',
                            style: TextStyle(
                                color: color,
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(filename,
                            style: const TextStyle(color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: _ok ? null : Colors.red.shade900,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_humanReason,
                    style: const TextStyle(color: Colors.white, height: 1.35)),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv(context, 'Signed by',
                        m.issuerId.isEmpty ? '(unset)' : m.issuerId),
                    _kv(context, 'When', issuedAt),
                    _kv(context, 'Original file', m.originalFilename),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('Technical details'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  _kv(context, 'Issuer pubkey',
                      m.issuerPubkeyShort.isEmpty
                          ? '(unset)'
                          : m.issuerPubkeyShort),
                  _kv(context, 'Content type', m.contentType),
                  _kv(context, 'Content hash', m.contentHashShort),
                  _kv(context, 'Original size', '${m.sizeBytes} bytes'),
                  _kv(context, 'Suite', m.suite),
                  _kv(context, 'Watermarks', '${m.watermarkCount}'),
                  _kv(context, 'Has recipient', m.hasRecipient ? 'yes' : 'no'),
                  if (result.failures.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Raw failure reasons',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    ...result.failures.map((f) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: SelectableText('• $f'),
                        )),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Bundle: ${result.bundleSizeBytes} bytes · verified locally · no network used',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: const TextStyle(color: Colors.white60)),
          ),
          Expanded(child: SelectableText(v)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- History

class HistoryEntry {
  final String id;
  final String filename;
  final int atUnix;
  final bool ok;
  final List<String> failures;
  final bool signatureValid;
  final BigInt bundleSizeBytes;
  final String fileId;
  final String issuerId;
  final String issuerPubkeyShort;
  final String originalFilename;
  final String contentType;
  final String contentHashShort;
  final BigInt sizeBytes;
  final BigInt issuedAtUnix;
  final String suite;
  final BigInt watermarkCount;
  final bool hasRecipient;

  HistoryEntry({
    required this.id,
    required this.filename,
    required this.atUnix,
    required this.ok,
    required this.failures,
    required this.signatureValid,
    required this.bundleSizeBytes,
    required this.fileId,
    required this.issuerId,
    required this.issuerPubkeyShort,
    required this.originalFilename,
    required this.contentType,
    required this.contentHashShort,
    required this.sizeBytes,
    required this.issuedAtUnix,
    required this.suite,
    required this.watermarkCount,
    required this.hasRecipient,
  });

  factory HistoryEntry.fromResult(String filename, VerifyResult r) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final m = r.manifest;
    return HistoryEntry(
      id: '${m.fileId}-$now',
      filename: filename,
      atUnix: now,
      ok: r.status == VerifyStatus.ok,
      failures: r.failures,
      signatureValid: r.signatureValid,
      bundleSizeBytes: BigInt.from(r.bundleSizeBytes.toInt()),
      fileId: m.fileId,
      issuerId: m.issuerId,
      issuerPubkeyShort: m.issuerPubkeyShort,
      originalFilename: m.originalFilename,
      contentType: m.contentType,
      contentHashShort: m.contentHashShort,
      sizeBytes: BigInt.from(m.sizeBytes.toInt()),
      issuedAtUnix: BigInt.from(m.issuedAtUnix.toInt()),
      suite: m.suite,
      watermarkCount: BigInt.from(m.watermarkCount.toInt()),
      hasRecipient: m.hasRecipient,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filename': filename,
        'atUnix': atUnix,
        'ok': ok,
        'failures': failures,
        'signatureValid': signatureValid,
        'bundleSizeBytes': bundleSizeBytes.toString(),
        'fileId': fileId,
        'issuerId': issuerId,
        'issuerPubkeyShort': issuerPubkeyShort,
        'originalFilename': originalFilename,
        'contentType': contentType,
        'contentHashShort': contentHashShort,
        'sizeBytes': sizeBytes.toString(),
        'issuedAtUnix': issuedAtUnix.toString(),
        'suite': suite,
        'watermarkCount': watermarkCount.toString(),
        'hasRecipient': hasRecipient,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        filename: j['filename'] as String,
        atUnix: j['atUnix'] as int,
        ok: j['ok'] as bool,
        failures: (j['failures'] as List).map((e) => e as String).toList(),
        signatureValid: j['signatureValid'] as bool,
        bundleSizeBytes: BigInt.parse(j['bundleSizeBytes'] as String),
        fileId: j['fileId'] as String,
        issuerId: j['issuerId'] as String,
        issuerPubkeyShort: j['issuerPubkeyShort'] as String,
        originalFilename: j['originalFilename'] as String,
        contentType: j['contentType'] as String,
        contentHashShort: j['contentHashShort'] as String,
        sizeBytes: BigInt.parse(j['sizeBytes'] as String),
        issuedAtUnix: BigInt.parse(j['issuedAtUnix'] as String),
        suite: j['suite'] as String,
        watermarkCount: BigInt.parse(j['watermarkCount'] as String),
        hasRecipient: j['hasRecipient'] as bool,
      );

  VerifyResult toVerifyResult() {
    return VerifyResult(
      status: ok ? VerifyStatus.ok : VerifyStatus.fail,
      bundleSizeBytes: bundleSizeBytes,
      signatureValid: signatureValid,
      failures: failures,
      manifest: ManifestSummary(
        fileId: fileId,
        issuerId: issuerId,
        issuerPubkeyShort: issuerPubkeyShort,
        originalFilename: originalFilename,
        contentType: contentType,
        contentHashShort: contentHashShort,
        sizeBytes: sizeBytes,
        issuedAtUnix: issuedAtUnix.toInt(),
        suite: suite,
        watermarkCount: watermarkCount,
        hasRecipient: hasRecipient,
      ),
    );
  }
}
