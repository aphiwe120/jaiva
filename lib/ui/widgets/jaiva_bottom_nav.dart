import 'package:flutter/material.dart';
import 'package:jaiva/ui/screens/home_screen.dart';
import 'package:jaiva/ui/screens/search_screen.dart';
import 'package:jaiva/ui/screens/library_screen.dart';

class JaivaBottomNav extends StatelessWidget {
  final int currentIndex;
  
  const JaivaBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        backgroundColor: const Color(0xFF121212), // Solid black background!
        selectedItemColor: const Color(0xFF1DB954),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == currentIndex) return; // Don't do anything if we tap the current tab
          
          Widget nextScreen;
          if (index == 0) nextScreen = const HomeScreen();
          else if (index == 1) nextScreen = const SearchScreen();
          else nextScreen = const LibraryScreen();

          // PushReplacement swaps the screen instantly without a "back button" animation
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation1, animation2) => nextScreen,
              transitionDuration: Duration.zero, // Makes it feel like an instant tab switch!
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
        ],
      ),
    );
  }
}