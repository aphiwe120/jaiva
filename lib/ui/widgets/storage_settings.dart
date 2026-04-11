import 'package:flutter/material.dart';
import 'package:jaiva/core/cache_config.dart';

class StorageSettingsWidget extends StatefulWidget {
  const StorageSettingsWidget({super.key});

  @override
  State<StorageSettingsWidget> createState() => _StorageSettingsWidgetState();
}

class _StorageSettingsWidgetState extends State<StorageSettingsWidget> {
  bool _isClearing = false;
  bool _isCacheCleared = false;

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);
    await CacheConfig.audioCache.emptyCache();
    await CacheConfig.imageCache.emptyCache();
    setState(() {
      _isClearing = false;
      _isCacheCleared = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.storage, color: Colors.white),
        title: const Text('Storage Manager', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: const Text('Audio & Image Local Caches (Max 200MB LRU)', style: TextStyle(color: Colors.white70, fontSize: 12)),
        trailing: _isClearing 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8), foregroundColor: Colors.white),
                onPressed: _isCacheCleared ? null : _clearCache,
                child: Text(_isCacheCleared ? 'Cleared!' : 'Clear RAM'),
              ),
      ),
    );
  }
}
