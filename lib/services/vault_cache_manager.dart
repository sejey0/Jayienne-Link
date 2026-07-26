import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Secure Vault Cache Manager.
/// Responsible for purging unencrypted temporary image files and Network Cache
/// immediately upon locking the app or exiting the Secret Media Vault.
class VaultCacheManager {
  static VaultCacheManager? _instance;

  VaultCacheManager._internal();

  /// Singleton Instance Accessor
  static VaultCacheManager get instance {
    _instance ??= VaultCacheManager._internal();
    return _instance!;
  }

  /// Purges all temporary media files and clears DefaultCacheManager memory/disk cache.
  Future<void> purgeVaultCache() async {
    try {
      debugPrint('[VaultCacheManager] Initiating emergency vault cache purge...');

      // 1. Clear Cached Network Images (DefaultCacheManager)
      await DefaultCacheManager().emptyCache();

      // 2. Clear custom temporary vault directory
      final tempDir = await getTemporaryDirectory();
      final vaultTempDir = Directory(p.join(tempDir.path, 'vault_cache'));

      if (await vaultTempDir.exists()) {
        final entities = await vaultTempDir.list().toList();
        for (final entity in entities) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            debugPrint('[VaultCacheManager] Error deleting cached entity ${entity.path}: $e');
          }
        }
        await vaultTempDir.delete(recursive: true);
      }

      debugPrint('[VaultCacheManager] Vault cache purged successfully.');
    } catch (e) {
      debugPrint('[VaultCacheManager] Error purging vault cache: $e');
    }
  }

  /// Get or create isolated temporary vault directory for transient media operations
  Future<Directory> getVaultTempDirectory() async {
    final tempDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(tempDir.path, '.vault_secure_temp'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }
}
