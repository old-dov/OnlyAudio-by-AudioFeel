import 'dart:async';
import 'dart:io';

import 'api_client.dart';

class DiscoveryService {
  /// Scan the local network subnet for an OnlyAudio server on port 5000.
  /// Returns a list of base URLs like "http://192.168.1.42:5000".
  Future<List<String>> scanNetwork({int port = 5000}) async {
    final results = <String>[];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );

    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        final parts = addr.address.split('.');
        if (parts.length != 4) continue;
        final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

        // Parallel scan: try all IPs 1-254 with short timeout
        final futures = <Future<String?>>[];
        for (var i = 1; i < 255; i++) {
          final ip = '$subnet.$i';
          futures.add(_probe(ip, port));
        }
        final found = await Future.wait(futures);
        results.addAll(found.whereType<String>());
      }
    }

    return results;
  }

  Future<String?> _probe(String ip, int port) async {
    final url = 'http://$ip:$port';
    try {
      final client = ApiClient(url);
      final ok = await client.discover();
      client.dispose();
      if (ok) return url;
    } catch (_) {
      // unreachable host
    }
    return null;
  }
}
