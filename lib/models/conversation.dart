class Conversation {
  final String id;
  final String listingId;
  final String tenantId;
  final String landlordId;
  final String? listingTitle;
  final String? tenantName;
  final String? landlordName;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  const Conversation({
    required this.id,
    required this.listingId,
    required this.tenantId,
    required this.landlordId,
    this.listingTitle,
    this.tenantName,
    this.landlordName,
    this.lastMessage,
    this.lastMessageAt,
  });

  /// Nom de l'autre personne de la conversation.
  String otherName(String myId) =>
      (myId == tenantId ? landlordName : tenantName) ?? 'Utilisateur';

  factory Conversation.fromMap(Map<String, dynamic> m) => Conversation(
        id: m['id'] as String,
        listingId: m['listing_id'] as String,
        tenantId: m['tenant_id'] as String,
        landlordId: m['landlord_id'] as String,
        listingTitle: (m['listing'] as Map?)?['title'] as String?,
        tenantName: (m['tenant'] as Map?)?['full_name'] as String?,
        landlordName: (m['landlord'] as Map?)?['full_name'] as String?,
        lastMessage: m['last_message'] as String?,
        lastMessageAt: m['last_message_at'] == null
            ? null
            : DateTime.parse(m['last_message_at'] as String),
      );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        conversationId: m['conversation_id'] as String,
        senderId: m['sender_id'] as String,
        body: m['body'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        readAt: m['read_at'] == null ? null : DateTime.parse(m['read_at'] as String),
      );
}
