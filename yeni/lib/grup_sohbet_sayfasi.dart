import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart'; // sendGroupChatNotification fonksiyonu için

class GrupSohbetSayfasi extends StatefulWidget {
  final bool
      isTeacher; // Mevcut kullanıcının öğretmen olup olmadığını bilmek için

  const GrupSohbetSayfasi({Key? key, required this.isTeacher})
      : super(key: key);

  @override
  State<GrupSohbetSayfasi> createState() => _GrupSohbetSayfasiState();
}

class _GrupSohbetSayfasiState extends State<GrupSohbetSayfasi> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _mesajController = TextEditingController();
  User? _currentUser;
  DocumentSnapshot? _currentUserDoc;

  // Sabit grup sohbeti ID'si
  static const String grupSohbetId =
      'main_class_chat_id'; // Bu ID'yi projenize göre değiştirebilirsiniz

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _kullaniciBilgileriniYukle();
  }

  Future<void> _kullaniciBilgileriniYukle() async {
    if (_currentUser != null) {
      _currentUserDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();
      if (mounted) {
        setState(
            () {}); // Kullanıcı bilgileri yüklendikten sonra arayüzü güncelle
      }
    }
  }

  Future<void> _mesajGonder() async {
    if (_mesajController.text.trim().isEmpty ||
        _currentUser == null ||
        _currentUserDoc == null ||
        !_currentUserDoc!.exists) {
      return;
    }

    final mesajMetni = _mesajController.text.trim();
    _mesajController.clear();

    final displayName =
        (_currentUserDoc!.data() as Map<String, dynamic>?)?['displayName'] ??
            _currentUser!.email ??
            'Anonim';

    try {
      await _firestore
          .collection('class_chats')
          .doc(grupSohbetId)
          .collection('messages')
          .add({
        'text': mesajMetni,
        'senderId': _currentUser!.uid,
        'senderDisplayName': displayName,
        'senderIsTeacher':
            widget.isTeacher, // Giriş yapan kullanıcının öğretmen durumu
        'timestamp': FieldValue.serverTimestamp(),
      });
      print('Mesaj gönderildi: $mesajMetni');

      // Mesaj gönderildikten sonra bildirim GÖNDERMEYE GEREK YOK, Cloud Function halledecek
      // sendGroupChatNotification(
      //   senderName: displayName,
      //   messageText: mesajMetni,
      //   senderId: _currentUser!.uid,
      // );
      // print('Grup mesajı bildirimi tetiklendi: $displayName tarafından');
    } catch (e) {
      print('Mesaj gönderme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e')),
        );
      }
    }
  }

  Widget _buildMesajItem(DocumentSnapshot mesajSnapshot) {
    final data = mesajSnapshot.data() as Map<String, dynamic>;
    final String senderId = data['senderId'] ?? '';
    final String senderDisplayName = data['senderDisplayName'] ?? 'Bilinmeyen';
    final bool senderIsTeacher = data['senderIsTeacher'] ?? false;
    final String text = data['text'] ?? '';
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;

    final bool benGonderdim = senderId == _currentUser?.uid;

    return Align(
      alignment: benGonderdim ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: benGonderdim
            ? (senderIsTeacher
                ? Colors.teal[100]
                : Colors.blue[100]) // Kendi mesajım (öğretmen/veli)
            : (senderIsTeacher
                ? Colors.orange[100]
                : Colors.grey[300]), // Başkasının mesajı (öğretmen/veli)
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: benGonderdim
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                senderIsTeacher
                    ? '$senderDisplayName (Öğretmen)'
                    : senderDisplayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: benGonderdim ? Colors.black87 : Colors.black54,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                timestamp != null
                    ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                    : '',
                style: TextStyle(
                  fontSize: 10,
                  color: benGonderdim ? Colors.black54 : Colors.black45,
                ),
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
        appBar: AppBar(title: const Text('Sınıf Sohbeti')),
        body: const Center(
            child: Text('Sohbete katılmak için giriş yapmalısınız.')),
      );
    }
    if (_currentUserDoc == null) {
      // Kullanıcı dokümanı hala yükleniyorsa
      return Scaffold(
        appBar: AppBar(title: const Text('Sınıf Sohbeti')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sınıf Sohbeti'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('class_chats')
                  .doc(grupSohbetId)
                  .collection('messages')
                  .orderBy('timestamp',
                      descending: false) // En eski mesaj üstte
                  .limit(100) // Son 100 mesajı göster (performans için)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print('Sohbet stream hatası: ${snapshot.error}');
                  return const Center(
                      child: Text('Mesajlar yüklenirken bir hata oluştu.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('Henüz mesaj yok. İlk mesajı siz gönderin!'));
                }

                final mesajlar = snapshot.data!.docs;

                return ListView.builder(
                  reverse:
                      true, // Yeni mesajlar altta görünsün ve otomatik scroll olsun diye
                  itemCount: mesajlar.length,
                  itemBuilder: (context, index) {
                    // Listeyi ters çevirdiğimiz için sondan başa doğru alıyoruz
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
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
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
