import 'package:flutter/material.dart';

import '../../models/conversation.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_client.dart';
import '../../utils/format.dart';
import 'chat_screen.dart';

/// Liste des conversations (une par logement et par locataire).
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final _service = ChatService();
  late Future<List<Conversation>> _future = _service.myConversations();

  Future<void> _reload() async {
    setState(() => _future = _service.myConversations());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser!.id;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Conversation>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(friendlyError(snap.error!), textAlign: TextAlign.center),
                ),
              ]);
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Aucune conversation pour le moment.',
                      textAlign: TextAlign.center),
                ),
              ]);
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = items[i];
                final name = c.otherName(myId);
                return ListTile(
                  leading: CircleAvatar(child: Text(name.isEmpty ? '?' : name[0].toUpperCase())),
                  title: Text(name),
                  subtitle: Text(
                    '${c.listingTitle ?? 'Annonce indisponible'}\n${c.lastMessage ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: c.lastMessageAt == null
                      ? null
                      : Text(formatTime(c.lastMessageAt!),
                          style: Theme.of(context).textTheme.bodySmall),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChatScreen(conversationId: c.id)));
                    _reload();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
