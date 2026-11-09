import 'package:flutter/material.dart';

import '../../models/conversation.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_client.dart';
import '../../utils/format.dart';
import '../listing/listing_detail_screen.dart';

/// Discussion en temps réel entre un locataire et un bailleur, à propos d'un logement.
class ChatScreen extends StatefulWidget {
  final String conversationId;
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatService();
  final _input = TextEditingController();
  late final Stream<List<ChatMessage>> _stream = _service.messages(widget.conversationId);
  late final Future<Conversation> _conversation =
      _service.getConversation(widget.conversationId);
  bool _sending = false;
  int _lastSeenCount = 0;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.send(widget.conversationId, text);
      _input.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser!.id;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<Conversation>(
          future: _conversation,
          builder: (_, s) => s.hasData
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.data!.otherName(myId)),
                  Text(s.data!.listingTitle ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis),
                ])
              : const Text('Discussion'),
        ),
        actions: [
          FutureBuilder<Conversation>(
            future: _conversation,
            builder: (_, s) => s.hasData
                ? IconButton(
                    tooltip: 'Voir le logement',
                    icon: const Icon(Icons.home_outlined),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listingId: s.data!.listingId))),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text(friendlyError(snap.error!)));
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final messages = snap.data!; // du plus récent au plus ancien
              if (messages.length != _lastSeenCount) {
                _lastSeenCount = messages.length;
                // Marque les messages reçus comme lus (sans bloquer l'affichage).
                if (messages.any((m) => m.senderId != myId && m.readAt == null)) {
                  _service.markRead(widget.conversationId).catchError((_) {});
                }
              }
              if (messages.isEmpty) {
                return const Center(
                    child: Text('Écrivez votre premier message au bailleur.'));
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final m = messages[i];
                  final mine = m.senderId == myId;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(m.body),
                          const SizedBox(height: 2),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(formatTime(m.createdAt),
                                style: Theme.of(context).textTheme.labelSmall),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(m.readAt == null ? Icons.done : Icons.done_all,
                                  size: 14,
                                  color: m.readAt == null ? null : scheme.primary),
                            ],
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Votre message',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
