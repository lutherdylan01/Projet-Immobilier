import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_client.dart';

/// Écran 3 (une seule fois) : nom + choix « bailleur » ou « locataire ».
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _auth = AuthService();
  UserRole? _role;
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Entrez votre nom');
      return;
    }
    if (_role == null) {
      setState(() => _error = 'Choisissez votre profil');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.updateProfile(fullName: _name.text.trim(), role: _role!);
      widget.onDone();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Widget _roleCard(UserRole role, IconData icon, String title, String subtitle) {
    final selected = _role == role;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        leading: Icon(icon, size: 36),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: selected ? Icon(Icons.check_circle, color: scheme.primary) : null,
        onTap: () => setState(() => _role = role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenue'),
        actions: [
          TextButton(onPressed: _auth.signOut, child: const Text('Annuler')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Votre nom complet'),
          ),
          const SizedBox(height: 24),
          const Text('Vous êtes :'),
          const SizedBox(height: 8),
          _roleCard(UserRole.locataire, Icons.search, 'Locataire',
              'Je cherche un logement'),
          _roleCard(UserRole.bailleur, Icons.home_work_outlined, 'Bailleur',
              'Je propose un ou plusieurs logements'),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
}
