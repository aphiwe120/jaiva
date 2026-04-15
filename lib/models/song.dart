import 'package:hive/hive.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final String thumbnailUrl;

  @HiveField(4)
  final String genre;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    this.genre = 'Unknown',
  });
}
