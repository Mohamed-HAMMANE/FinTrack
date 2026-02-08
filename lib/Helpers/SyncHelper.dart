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
    final serverUrl = prefs.getString('server_ip');
    if (serverUrl == null || serverUrl.isEmpty) {
      Func.showToast(
        'Server URL not configured. Go to Sync Settings.',
        type: 'error',
      );
      return false;
    }
    return syncDatabase(serverUrl);
  }

  static Future<bool> syncDatabase(String serverAddress) async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFilePath = join(dbPath, 'fin_track.db');
      final dbFile = File(dbFilePath);

      if (!await dbFile.exists()) {
        Func.showToast('Database file not found!', type: 'error');
        return false;
      }

      final url = _buildSyncUri(serverAddress);

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
    } on FormatException {
      Func.showToast('Invalid server URL. Example: http://localhost:3020', type: 'error');
      return false;
    } catch (e) {
      // print('Sync error: $e');
      return false;
    }
  }

  static Uri _buildSyncUri(String serverAddress) {
    final trimmed = serverAddress.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Empty server address');
    }

    final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed);
    final normalizedAddress = hasScheme ? trimmed : 'http://$trimmed';
    final baseUri = Uri.parse(normalizedAddress);
    final scheme = baseUri.scheme.toLowerCase();

    if ((scheme != 'http' && scheme != 'https') ||
        !baseUri.hasAuthority ||
        baseUri.host.isEmpty) {
      throw const FormatException('Invalid server address');
    }

    final currentPath = baseUri.path.isEmpty ? '/' : baseUri.path;
    final pathWithoutTrailingSlash = currentPath.endsWith('/')
        ? currentPath.substring(0, currentPath.length - 1)
        : currentPath;

    final syncPath = pathWithoutTrailingSlash.endsWith('/api/sync')
        ? pathWithoutTrailingSlash
        : '$pathWithoutTrailingSlash/api/sync';

    return baseUri.replace(path: syncPath);
  }
}
