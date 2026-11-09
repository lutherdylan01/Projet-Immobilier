import 'package:flutter/material.dart';

import '../models/profile.dart';
import 'chat/conversations_screen.dart';
import 'listing/my_listings_screen.dart';
import 'profile/profile_screen.dart';
import 'search/search_screen.dart';
import 'visits/visits_screen.dart';

/// Écran principal avec la barre de navigation du bas.
/// Le premier onglet dépend du rôle : recherche (locataire) ou mes logements (bailleur).
class HomeScreen extends StatefulWidget {
  final Profile profile;
  final VoidCallback onProfileChanged;
  const HomeScreen({super.key, required this.profile, required this.onProfileChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final landlord = widget.profile.isLandlord;
    final pages = [
      landlord ? const MyListingsScreen() : const SearchScreen(),
      const ConversationsScreen(),
      VisitsScreen(profile: widget.profile),
      ProfileScreen(profile: widget.profile, onChanged: widget.onProfileChanged),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          landlord
              ? const NavigationDestination(
                  icon: Icon(Icons.home_work_outlined), label: 'Mes logements')
              : const NavigationDestination(icon: Icon(Icons.search), label: 'Rechercher'),
          const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          const NavigationDestination(
              icon: Icon(Icons.event_available_outlined), label: 'Visites'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
