import '../models/conversation.dart';
import 'supabase_client.dart';

class ChatService {
  /// Ouvre (ou retrouve) la conversation avec le bailleur d'un logement.
  Future<String> openConversation(String listingId) async {
    final id = await supabase.rpc(
      'get_or_create_conversation',
      params: {'p_listing_id': listingId},
    );
    return id as String;
  }

  Future<List<Conversation>> myConversations() async {
    final rows = await supabase
        .from('conversations')
        .select('*, listing:listings(title), '
            'tenant:profiles!conversations_tenant_id_fkey(full_name), '
            'landlord:profiles!conversations_landlord_id_fkey(full_name)')
        .order('last_message_at', ascending: false, nullsFirst: false);
    return rows.map(Conversation.fromMap).toList();
  }

  Future<Conversation> getConversation(String id) async {
    final row = await supabase
        .from('conversations')
        .select('*, listing:listings(title), '
            'tenant:profiles!conversations_tenant_id_fkey(full_name), '
            'landlord:profiles!conversations_landlord_id_fkey(full_name)')
        .eq('id', id)
        .single();
    return Conversation.fromMap(row);
  }

  /// Flux temps réel des 200 derniers messages d'une conversation.
  Stream<List<ChatMessage>> messages(String conversationId) => supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: false)
      .limit(200)
      .map((rows) => rows.map(ChatMessage.fromMap).toList());

  Future<void> send(String conversationId, String body) =>
      supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': currentUserId,
        'body': body.trim(),
      });

  Future<void> markRead(String conversationId) => supabase.rpc(
        'mark_conversation_read',
        params: {'p_conversation_id': conversationId},
      );
}
