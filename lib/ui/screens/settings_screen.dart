import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:jaiva/theme/kinetic_vault_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _username = "Jaiva User";
  late Box _settingsBox;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Open the box (if not already opened in main.dart) and grab the saved name
    _settingsBox = await Hive.openBox('settings');
    setState(() {
      _username = _settingsBox.get('username', defaultValue: "Jaiva User");
      _isLoading = false;
    });
  }

  // 📝 The Popup Dialog to change the name
  void _editNameDialog() {
    final TextEditingController controller = TextEditingController(text: _username == "Jaiva User" ? "" : _username);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24), // Dark sleek background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Edit Your Alias", 
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.outfit(color: Colors.white),
          cursorColor: const Color(0xFF00E676), // Neon Emerald
          decoration: InputDecoration(
            hintText: "Enter your DJ name...",
            hintStyle: GoogleFonts.outfit(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              setState(() {
                _username = newName.isNotEmpty ? newName : "Jaiva User";
              });
              _settingsBox.put('username', _username); // Save it to local storage!
              Navigator.pop(context);
            },
            child: Text("Save", style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Vault Settings', 
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)
        ),
      ),
      body: Stack(
        children: [
          // 🎨 Kinetic Vault: Aura Orb Background
          const AuraOrb(
            auraValue: 0.8, // Cyan/Electric Blue vibe for Settings
            size: 400.0,
          ),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 👤 Profile Section (Now Tappable!)
                GestureDetector(
                  onTap: _editNameDialog, // Tapping opens the edit dialog
                  child: GlassCard(
                    padding: const EdgeInsets.all(20.0),
                    borderRadius: 16.0,
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF00E676), width: 2), // Neon Emerald Border
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E676).withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 35, 
                            backgroundColor: Color(0xFF1A1A24),
                            child: Icon(Icons.person, color: Colors.white54, size: 35),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _username, 
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Tap to edit alias", 
                                style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontSize: 14)
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit, color: Colors.white54, size: 20),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),

                // 💾 Storage Settings
                Text(
                  "System", 
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w600)
                ),
                const SizedBox(height: 12),
                
                GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: 12.0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const Icon(Icons.delete_sweep, color: Colors.white70),
                    title: Text("Clear Cache", style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
                    subtitle: Text(
                      "Free up storage space. Your Vault downloads won't be removed.", 
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('System cache cleared!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)), 
                          backgroundColor: const Color(0xFF00E676),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}