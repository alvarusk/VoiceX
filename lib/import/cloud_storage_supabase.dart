import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../sync/supabase_manager.dart';

class CloudStorage {
  CloudStorage();

  final _supabase = SupabaseManager.instance;

  Future<String> upload({
    required String bucket,
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async {
    try {
      await _supabase.init();
      if (!_supabase.isReady) {
        throw Exception('Supabase no inicializado');
      }
      final client = Supabase.instance.client;
      final data = Uint8List.fromList(bytes);
      await client.storage.from(bucket).uploadBinary(
            path,
            data,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return await client.storage.from(bucket).createSignedUrl(
            path,
            60 * 60 * 24 * 365,
          );
    } catch (e) {
      debugPrint('[import.storage] upload failed bucket=$bucket path=$path error=$e');
      rethrow;
    }
  }
}
