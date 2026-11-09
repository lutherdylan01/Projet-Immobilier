import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_client.dart';
import '../../utils/format.dart';

/// Profil : nom, numéro WhatsApp, changement de rôle, déconnexion.
class ProfileScreen extends StatefulWidget {
  final Profile profile;
  final VoidCallback onChanged;
  const ProfileScreen({super.key, required this.profile, required this.onChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _whatsapp = TextEditingController(text: widget.profile.whatsapp);
  late UserRole _role = widget.profile.role!;
  bool _saving = false;

  Future<void> _save() async {
    String? whatsapp;
    if (_whatsapp.text.trim().isNotEmpty) {
      whatsapp = normalizeCameroonPhone(_whatsapp.text);
      if (whatsapp == null) {
        _snack('Numéro WhatsApp invalide');
        return;
      }
    }
    setState(() => _saving = true);
    try {
      await _auth.updateProfile(
          fullName: _name.text.trim(), role: _role, whatsapp: whatsapp);
      _snack('Profil enregistré');
      widget.onChanged();
    } catch (e) {
      _snack(friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  void dispose() {
    _name.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined),
            title: Text(widget.profile.phone ?? ''),
            subtitle: const Text('Numéro vérifié'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nom complet'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro WhatsApp (si différent)',
              prefixText: '+237 ',
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(value: UserRole.locataire, label: Text('Locataire')),
              ButtonSegment(value: UserRole.bailleur, label: Text('Bailleur')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Enregistrer'),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _auth.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}
