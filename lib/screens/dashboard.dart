import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../api.dart';
import 'devices.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tab = 0;
  int _online = 0;
  int _total = 0;
  int _fps = 0;

  @override
  void initState() {
    super.initState();
    _poll();
    _ticker();
  }

  void _ticker() {
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;
      _poll();
      _ticker();
    });
  }

  Future<void> _poll() async {
    try {
      final d = await Api.get('/api/stats');
      if (!mounted) return;
      setState(() {
        _online = (d['onlineUsers'] ?? 0) as int;
        _total = (d['totalTargets'] ?? 0) as int;
        _fps = (d['activeConnections'] ?? 0) as int;
      });
    } catch (_) {}
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _stat(String label, String val, IconData icon, Color c) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: T.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(color: c.withOpacity(0.12), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c, size: 16),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  fontFamily: T.mono,
                  color: c,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            val,
            style: const TextStyle(
              fontFamily: T.mono,
              color: T.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _home() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [T.card, T.surface],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.red.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 54,
                      height: 54,
                      color: T.red.withOpacity(0.2),
                      child: const Center(
                        child: Text('LOGO', style: TextStyle(color: T.red, fontSize: 10, fontFamily: T.mono)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VOIDHAND',
                      style: TextStyle(
                        fontFamily: T.mono,
                        color: T.red,
                        fontSize: 20,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Hanz Dev Official',
                      style: TextStyle(
                        fontFamily: T.ui,
                        color: T.dim,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: [
              _stat('ONLINE', '$_online', FontAwesomeIcons.wifi, T.red),
              _stat('TOTAL', '$_total', FontAwesomeIcons.mobileScreen, T.white),
              _stat('ACTIVE', '$_fps', FontAwesomeIcons.cube, T.red),
              _stat('VERSION', '1.0.0', FontAwesomeIcons.code, T.white),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _footer(
                  'TELEGRAM',
                  FontAwesomeIcons.telegram,
                  () => _open('https://t.me/hanzdev'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _footer(
                  'SUPPORT',
                  FontAwesomeIcons.solidHeart,
                  () => _open('https://saweria.co/hanzreally'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'hanzzcodee@gmail.com',
              style: TextStyle(
                fontFamily: T.ui,
                color: T.faint,
                fontSize: 11,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(String label, IconData icon, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: T.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.red.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: T.red, size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: T.mono,
                color: T.white,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nav(IconData icon, String label, int i) {
    final sel = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? T.red.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: sel ? Border.all(color: T.red.withOpacity(0.5)) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: sel ? T.red : T.dim, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: T.ui,
                color: sel ? T.white : T.dim,
                fontSize: 10,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              ),
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
      appBar: AppBar(
        title: const Text('VOIDHAND'),
        centerTitle: true,
      ),
      body: _tab == 0 ? _home() : const DevicesScreen(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: T.surface,
          border: Border(top: BorderSide(color: T.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _nav(Icons.home_rounded, 'HOME', 0),
                _nav(Icons.devices_rounded, 'DEVICES', 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
