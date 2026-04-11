import 'package:hive/hive.dart';
import 'song.dart';

part 'playlist.g.dart';

@HiveType(typeId: 1)
class Playlist {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    this.songs = const [],
  });
}
