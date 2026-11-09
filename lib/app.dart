import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/profile.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/phone_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

class LogementApp extends StatelessWidget {
  const LogementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logement CM',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Choisit l'écran à afficher selon l'état de connexion :
/// pas connecté -> saisie du numéro ; profil incomplet -> choix du rôle ;
/// sinon -> accueil.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _auth.authStateChanges,
      builder: (context, _) {
        if (_auth.currentUser == null) return const PhoneScreen();
        return FutureBuilder<Profile?>(
          // La clé force un nouveau chargement quand l'utilisateur change.
          key: ValueKey(_auth.currentUser!.id),
          future: _auth.loadMyProfile(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snap.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Impossible de charger le profil.\nVérifiez votre connexion.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final profile = snap.data;
            if (profile == null || !profile.isComplete) {
              return OnboardingScreen(onDone: () => setState(() {}));
            }
            return HomeScreen(
              profile: profile,
              onProfileChanged: () => setState(() {}),
            );
          },
        );
      },
    );
  }
}
