import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/supabase_client.dart';
import '../../utils/format.dart';
import 'otp_screen.dart';

/// Écran 1 de l'inscription / connexion : saisie du numéro de téléphone.
class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _controller = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final phone = normalizeCameroonPhone(_controller.text);
    if (phone == null) {
      setState(() => _error = 'Numéro invalide. Exemple : 6 90 12 34 56');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.sendOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
      );
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Icon(Icons.home_work_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Logement CM',
                textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Trouvez ou proposez un logement au Cameroun.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                labelText: 'Votre numéro de téléphone',
                prefixText: '+237 ',
                hintText: '6 90 12 34 56',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Recevoir le code par SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
