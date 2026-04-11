import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jaiva/models/song.dart';

class DownloadService {
  static Future<void> downloadSong(BuildContext context, Song song) async {
    final downloadsBox = Hive.box<Song>('downloads');

    // 1. Check if already downloaded
    if (downloadsBox.values.any((s) => s.id == song.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already downloaded!'), backgroundColor: Colors.green),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Downloading ${song.title}...'), backgroundColor: Colors.grey[900]),
    );

    final ytExplode = YoutubeExplode();
    
    try {
      // 2. Bypass restrictions and get the stream
      final manifest = await ytExplode.videos.streamsClient.getManifest(
        song.id,
        ytClients: [YoutubeApiClient.safari, YoutubeApiClient.androidVr],
      );
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      final stream = ytExplode.videos.streamsClient.get(audioStreamInfo);

      // 3. Create a hidden file on the device
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${song.id}.mp4'); // Save using the YouTube ID

      // 4. Pipe the bytes directly to the file (Saves RAM!)
      final fileStream = file.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();

      // 5. Save the record to our local database
      downloadsBox.add(song);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ ${song.title} Downloaded!'), backgroundColor: Colors.green),
      );

    } catch (e) {
      print('❌ Download failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download failed. Please try again.'), backgroundColor: Colors.red),
      );
    } finally {
      ytExplode.close();
    }
  }
}