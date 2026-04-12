import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/discovery_service.dart';
import 'remote_player_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final _ipController = TextEditingController();
  final _discoveryService = DiscoveryService();
  bool _scanning = false;
  bool _connecting = false;
  List<String> _foundServers = [];
  String? _error;

  static const _prefKey = 'last_server_ip';

  @override
  void initState() {
    super.initState();
    _loadSavedIp();
  }

  Future<void> _loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && saved.isNotEmpty) {
      _ipController.text = saved;
    }
  }

  Future<void> _saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, ip);
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _foundServers = [];
      _error = null;
    });
    try {
      final results = await _discoveryService.scanNetwork();
      setState(() {
        _foundServers = results;
        _scanning = false;
        if (results.isEmpty) {
          _error = 'Aucun serveur OnlyAudio trouvé sur le réseau';
        }
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _error = 'Erreur de scan: $e';
      });
    }
  }

  Future<void> _connect(String baseUrl) async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final client = ApiClient(baseUrl);
      final ok = await client.discover();
      if (!ok) {
        client.dispose();
        setState(() {
          _connecting = false;
          _error = 'Serveur non reconnu à $baseUrl';
        });
        return;
      }
      // Extract IP for saving
      final uri = Uri.parse(baseUrl);
      await _saveIp(uri.host);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RemotePlayerScreen(api: client),
        ),
      );
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = 'Connexion impossible: $e';
      });
    }
  }

  void _connectManual() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    final url = ip.contains('://') ? ip : 'http://$ip:5000';
    _connect(url);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              const Icon(
                Icons.headphones_rounded,
                size: 72,
                color: Color(0xFF31A9FF),
              ),
              const SizedBox(height: 16),
              const Text(
                'OnlyAudio Remote',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Connectez-vous au lecteur desktop',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 36),

              // --- Manual IP ---
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: '192.168.x.x',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF141922),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _connecting ? null : _connectManual,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF31A9FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _connecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('CONNECTER',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Divider ---
              Row(
                children: [
                  const Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('ou',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
                  ),
                  const Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 20),

              // --- Auto discover ---
              OutlinedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_find_rounded),
                label: Text(_scanning
                    ? 'SCAN EN COURS...'
                    : 'RECHERCHER SUR LE RÉSEAU'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFF31A9FF)),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ],

              // --- Found servers ---
              if (_foundServers.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Serveurs trouvés:',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _foundServers.length,
                    itemBuilder: (context, i) {
                      final url = _foundServers[i];
                      return Card(
                        color: const Color(0xFF141922),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.computer_rounded,
                              color: Color(0xFF18D1B5)),
                          title: Text(url,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('OnlyAudio Desktop'),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16),
                          onTap: () => _connect(url),
                        ),
                      );
                    },
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
