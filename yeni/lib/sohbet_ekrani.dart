import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SohbetEkrani extends StatefulWidget {
  final String chatId; // İki kullanıcı arasındaki benzersiz sohbet ID'si
  final String recipientId; // Mesaj gönderilecek/alınacak kişinin UID'si
  final String recipientName; // Alıcının adı (AppBar başlığı için)

  const SohbetEkrani({
    Key? key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
  }) : super(key: key);

  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _mesajController = TextEditingController();
  User? _currentUser;
  // DocumentSnapshot? _currentUserDoc; // Belki gönderen adını almak için gerekebilir ama şimdilik chatId yetiyor

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // Gerekirse mevcut kullanıcı bilgilerini yükle (örn: displayName)
    // _loadCurrentUserDoc();
  }

  // Future<void> _loadCurrentUserDoc() async {
  //   if (_currentUser != null) {
  //     _currentUserDoc = await _firestore.collection('users').doc(_currentUser!.uid).get();
  //     if (mounted) setState(() {});
  //   }
  // }

  Future<void> _mesajGonder() async {
    if (_mesajController.text.trim().isEmpty || _currentUser == null) {
      return;
    }

    final mesajMetni = _mesajController.text.trim();
    final String currentUserId = _currentUser!.uid;
    // İsteğe bağlı: Gönderen adını mesajla birlikte saklamak için
    final String currentUserDisplayName = _currentUser!.displayName ??
        _currentUser!.email ??
        'Bilinmeyen Kullanıcı';

    _mesajController.clear(); // Metin alanını erkenden temizle

    try {
      // 1. ÖNCE private_chats/{chatId} ana belgesini güncelle/oluştur (users alanı burada kritik)
      // Bu, messages koleksiyonuna yazma kuralının geçmesini sağlar.
      await _firestore.collection('private_chats').doc(widget.chatId).set({
        'lastMessage': mesajMetni,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'users': [
          currentUserId,
          widget.recipientId
        ], // Konuşmadaki kullanıcıların UID'leri
        // Katılımcıların displayName'lerini de saklamak sohbet listesi için faydalı olabilir
        'userDisplayNames': {
          currentUserId: currentUserDisplayName,
          widget.recipientId:
              widget.recipientName, // Alıcı adı zaten widget'ta var
        },
        // Okunmamış mesaj sayıları burada güncellenebilir (daha ileri seviye)
        // '${widget.recipientId}_unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true)); // Varolan diğer alanları koru, yoksa oluştur

      // 2. SONRA mesajı private_chats/{chatId}/messages altına ekle
      await _firestore
          .collection('private_chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': mesajMetni,
        'senderId': currentUserId,
        'senderDisplayName': currentUserDisplayName, // Mesajda da saklayalım
        'timestamp': FieldValue.serverTimestamp(),
        'recipientId': widget.recipientId, // Bilgi amaçlı
      });

      print('Özel Mesaj gönderildi: $mesajMetni, Chat ID: ${widget.chatId}');
    } catch (e) {
      print('Özel Mesaj gönderme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e')),
        );
        // Başarısız olursa metni geri yükle (isteğe bağlı)
        // _mesajController.text = mesajMetni;
      }
    }
  }

  Widget _buildMesajItem(DocumentSnapshot mesajSnapshot) {
    final data = mesajSnapshot.data() as Map<String, dynamic>;
    final String senderId = data['senderId'] ?? '';
    // final String senderDisplayName = data['senderDisplayName'] ?? 'Bilinmeyen'; // Eğer mesajda saklanıyorsa
    final String senderDisplayName = data['senderDisplayName'] ??
        (senderId == _currentUser?.uid ? 'Siz' : widget.recipientName);
    final String text = data['text'] ?? '';
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;

    final bool benGonderdim = senderId == _currentUser?.uid;

    // Gönderen adını almak için (eğer mesajda saklanmıyorsa, users koleksiyonundan alınabilir - daha karmaşık)
    // Şimdilik sadece hizalama ile kimin gönderdiğini belirtiyoruz.

    return Align(
      alignment: benGonderdim ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: benGonderdim ? Colors.blue[100] : Colors.grey[300],
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: benGonderdim
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // İsteğe bağlı: Gönderen adını burada gösterebilirsiniz
              Text(senderDisplayName,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: benGonderdim ? Colors.blueGrey : Colors.black54)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                timestamp != null
                    ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                    : '',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.recipientName)),
        body: const Center(
            child: Text('Sohbete katılmak için giriş yapmalısınız.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipientName),
        backgroundColor: Colors.greenAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection(
                      'private_chats') // Özel sohbetler için koleksiyon adı
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp',
                      descending: false) // En eski mesaj üstte
                  .limit(100) // Son 100 mesajı göster
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Özel sohbet stream hatası: ${snapshot.error}');
                  return const Center(
                      child: Text('Mesajlar yüklenirken bir hata oluştu.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                      child: Text(
                          'Henüz hiç mesaj yok. ${widget.recipientName} kişisine ilk mesajı siz gönderin!'));
                }

                final mesajlar = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, // Yeni mesajlar altta görünsün
                  itemCount: mesajlar.length,
                  itemBuilder: (context, index) {
                    final mesajDoc = mesajlar[mesajlar.length - 1 - index];
                    return _buildMesajItem(mesajDoc);
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mesajController,
                    decoration: const InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _mesajGonder(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.greenAccent),
                  onPressed: _mesajGonder,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
