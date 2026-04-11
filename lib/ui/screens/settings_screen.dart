import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Row(
            children: [
              const CircleAvatar(radius: 30, backgroundImage: NetworkImage('https://via.placeholder.com/150')),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Jaiva User", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("View Profile", style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Data Saver Settings
          const Text("Data Saver", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text("Audio Quality", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Sets audio quality to low and disables lyrics video backgrounds.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            value: false,
            activeColor: const Color(0xFF1DB954),
            onChanged: (val) {},
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(color: Colors.white24, height: 32),

          // Storage Settings
          const Text("Storage", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Clear cache", style: TextStyle(color: Colors.white)),
            subtitle: const Text("Free up storage space. Your downloads won't be removed.", style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared!'), backgroundColor: Color(0xFF1DB954)),
              );
            },
          ),
        ],
      ),
    );
  }
}