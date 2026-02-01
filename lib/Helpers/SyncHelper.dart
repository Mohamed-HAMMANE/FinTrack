import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../Helpers/Funcs.dart';

class SyncHelper {
  static const String apiKey = 'fintrack_local_sync_123';

  static Future<bool> syncWithSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('server_ip');
    if (ip == null || ip.isEmpty) {
      Func.showToast(
        'Server IP not configured. Go to Sync Settings.',
        type: 'error',
      );
      return false;
    }
    return syncDatabase(ip);
  }

  static Future<bool> syncDatabase(String computerIp) async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFilePath = join(dbPath, 'fin_track.db');
      final dbFile = File(dbFilePath);

      if (!await dbFile.exists()) {
        Func.showToast('Database file not found!', type: 'error');
        return false;
      }

      final url = Uri.parse('http://$computerIp:3000/api/sync');

      var request = http.MultipartRequest('POST', url);
      request.headers['x-api-key'] = apiKey;

      request.files.add(await http.MultipartFile.fromPath('file', dbFile.path));

      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        // print('Sync failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      // print('Sync error: $e');
      return false;
    }
  }
}
