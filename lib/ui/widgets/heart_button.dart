import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jaiva/models/song.dart';

/// Heart button for liking/favoriting songs with Hive persistence
class HeartButton extends StatelessWidget {
  final Song currentSong;

  const HeartButton({super.key, required this.currentSong});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Song>>(
      valueListenable: Hive.box<Song>('likes').listenable(),
      builder: (context, box, _) {
        final isHearted = box.values.any((song) => song.id == currentSong.id);

        return IconButton(
          icon: Icon(
            isHearted ? Icons.favorite : Icons.favorite_border,
            color: isHearted ? Colors.red : Colors.grey,
          ),
          onPressed: () {
            if (isHearted) {
              // Remove from likes
              final index = box.values.toList().indexWhere((s) => s.id == currentSong.id);
              if (index != -1) box.deleteAt(index);
            } else {
              // Add to likes
              box.add(currentSong);
            }
          },
        );
      },
    );
  }
}
