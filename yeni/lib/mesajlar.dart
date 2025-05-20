import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Geri eklendi
import 'package:cloud_firestore/cloud_firestore.dart'; // Geri eklendi

// Grup Sohbet Sayfası için import (bir sonraki adımda oluşturulacak)
import 'grup_sohbet_sayfasi.dart';
import 'kullanici_listesi_sayfasi.dart'; // Yeni import

// Örnek Sohbet Ekranı (şimdilik çok basit) - BU KISIM DAHA SONRA BİREBİR MESAJLAR İÇİN KULLANILACAK
class SohbetEkrani extends StatefulWidget {
  final String gesprekId;
  final String mevcutKullaniciId;
  final bool benOgretmenMiyim;
  // Birebir sohbet için eklenenler (KullaniciListesiSayfasi bunları bekliyor olabilir)
  final String? chatId;
  final String? recipientId;
  final String? recipientName;

  const SohbetEkrani({
    Key? key,
    this.gesprekId = '', // Varsayılan değer, birebir sohbette kullanılmayacaksa
    required this.mevcutKullaniciId,
    required this.benOgretmenMiyim,
    this.chatId, // Birebir sohbet için
    required this.recipientId, // Birebir sohbet için
    required this.recipientName, // Birebir sohbet için
  }) : super(key: key);

  @override
  _SohbetEkraniState createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  late String _currentChatId;
  Stream<QuerySnapshot>? _messagesStream;
  bool _isSending = false;
  bool _isLoadingInitially = true; // Stream başlamadan önceki ilk yükleme için

  @override
  void initState() {
    super.initState();
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      _currentChatId = widget.chatId!;
      _initMessagesStream();
    } else {
      _currentChatId = '';
      setState(() {
        _isLoadingInitially = false; // Yeni sohbette stream hemen başlamaz
      });
    }
  }

  void _initMessagesStream() {
    if (_currentChatId.isEmpty) {
      print(
          "_initMessagesStream: _currentChatId is empty, cannot init stream.");
      setState(() => _isLoadingInitially = false); // Stream başlatılamadı
      return;
    }
    print(
        "_initMessagesStream: Initializing stream for chat ID: $_currentChatId");
    _messagesStream = _firestore
        .collection('private_chats')
        .doc(_currentChatId)
        .collection('messages')
        .orderBy('timestamp',
            descending:
                true) // Yeniler üste gelecek şekilde (ListView reverse: true ile)
        .snapshots();
    setState(() {
      _isLoadingInitially = false; // Stream dinlenmeye başlandı
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || widget.recipientId == null) {
      return;
    }
    setState(() => _isSending = true);

    String messageText = _messageController.text.trim();
    String currentUserId = widget.mevcutKullaniciId;
    String recipientId = widget.recipientId!;
    String senderDisplayName =
        FirebaseAuth.instance.currentUser?.displayName ?? "Kullanıcı";

    String tempChatId = _currentChatId; // Mevcut chatId'yi sakla

    try {
      if (tempChatId.isEmpty) {
        List<String> participants = [currentUserId, recipientId]..sort();
        QuerySnapshot existingChatCheck = await _firestore
            .collection('private_chats')
            .where('participants', isEqualTo: participants)
            .limit(1)
            .get();

        if (existingChatCheck.docs.isNotEmpty) {
          tempChatId = existingChatCheck.docs.first.id;
        } else {
          DocumentReference chatDocRef =
              _firestore.collection('private_chats').doc();
          tempChatId = chatDocRef.id;
          await chatDocRef.set({
            'participants': participants,
            'lastMessage': messageText,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'lastMessageSenderId': currentUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        // Yeni _currentChatId set edildikten sonra stream'i başlat
        if (mounted && _currentChatId != tempChatId) {
          // Sadece gerçekten değiştiyse veya ilk kez set ediliyorsa
          _currentChatId = tempChatId;
          _initMessagesStream();
        }
      } else {
        // Var olan sohbet, stream zaten dinliyor olmalı.
      }

      await _firestore
          .collection('private_chats')
          .doc(tempChatId) // tempChatId kullanılıyor
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'recipientId': recipientId,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'senderDisplayName': senderDisplayName,
      });

      await _firestore.collection('private_chats').doc(tempChatId).update({
        'lastMessage': messageText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
      });

      _messageController.clear();
    } catch (e) {
      print("Mesaj gönderilirken hata: $e");
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.recipientName ??
        (widget.gesprekId.isNotEmpty ? 'Grup: ${widget.gesprekId}' : 'Sohbet');

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingInitially
                ? const Center(
                    child: CircularProgressIndicator(
                        key: ValueKey("init_loading")))
                : _messagesStream ==
                        null // Eğer yeni sohbet ve henüz mesaj gönderilmediyse stream null olabilir
                    ? Center(
                        child: Text('Sohbete başlayın!',
                            key: ValueKey("start_chat_text")))
                    : StreamBuilder<QuerySnapshot>(
                        key: ValueKey(
                            _currentChatId), // Chat ID değiştiğinde StreamBuilder'ı yeniden oluşturmak için
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    key: ValueKey("stream_waiting")));
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                                child: Text('Henüz mesaj yok.',
                                    key: ValueKey("no_messages_text")));
                          }
                          if (snapshot.hasError) {
                            print(
                                "StreamBuilder Error: ${snapshot.error}"); // Hata logu
                            return const Center(
                                child: Text('Mesajlar yüklenemedi.',
                                    key: ValueKey("stream_error_text")));
                          }

                          final messagesDocs = snapshot.data!.docs;

                          return ListView.builder(
                            itemCount: messagesDocs.length,
                            reverse: true,
                            itemBuilder: (context, index) {
                              final message = messagesDocs[index].data()
                                  as Map<String, dynamic>;
                              final bool isMe = message['senderId'] ==
                                  widget.mevcutKullaniciId;
                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  color: isMe
                                      ? Colors.teal[100]
                                      : Colors.grey[300],
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Text(message['text'] ?? ''),
                                  ),
                                ),
                              );
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
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Mesajınızı yazın...',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isSending,
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.teal),
                        onPressed: _sendMessage,
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class MesajlarSayfasi extends StatefulWidget {
  final bool isTeacher;
  const MesajlarSayfasi({Key? key, required this.isTeacher}) : super(key: key);

  @override
  _MesajlarSayfasiState createState() => _MesajlarSayfasiState();
}

class _MesajlarSayfasiState extends State<MesajlarSayfasi> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // _privateChatList yerine _usersForChattingList kullanacağız
  List<DocumentSnapshot> _usersForChattingList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _loadUsersForChatting(); // Fonksiyon adı değişti
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = "Kullanıcıları görmek için giriş yapmalısınız.";
      });
    }
  }

  Future<void> _loadUsersForChatting() async {
    if (_currentUser == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      QuerySnapshot querySnapshot;
      if (widget.isTeacher) {
        // Öğretmen ise, velileri (isTeacher == false VE userRole == 'veli') listele
        querySnapshot = await _firestore
            .collection('users')
            .where('isTeacher', isEqualTo: false)
            .where('userRole', isEqualTo: 'veli')
            // .orderBy('displayName') // İsteğe bağlı sıralama
            .get();
      } else {
        // Veli ise, öğretmenleri (isTeacher == true) listele
        querySnapshot = await _firestore
            .collection('users')
            .where('isTeacher', isEqualTo: true)
            // .orderBy('displayName') // İsteğe bağlı sıralama
            .get();
      }

      // Mevcut kullanıcıyı listeden çıkar (kendisiyle sohbet etmemesi için)
      // Bu kontrol gereksiz olabilir çünkü öğretmen velileri, veli öğretmenleri listeliyor.
      // Ancak bir öğretmen başka bir öğretmenle veya veli başka bir veliyle konuşmak isterse
      // diye genel bir listeden kendi ID'sini çıkarma mantığı eklenebilir.
      // Şimdiki mantıkla (öğretmen<->veli) bu filtrelemeye gerek yok.

      setState(() {
        _usersForChattingList = querySnapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      print("Sohbet edilecek kullanıcıları yüklerken hata: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Kullanıcı listesi yüklenirken bir sorun oluştu.";
      });
    }
  }

  // _getRecipientDetails zaten kullanıcı detaylarını getiriyor, bu kullanılabilir.
  Future<Map<String, String?>> _getUserDetails(String userId) async {
    if (userId.isEmpty) return {'name': 'Bilinmeyen', 'photoUrl': null};
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'name': data['displayName'] ?? 'Kullanıcı',
          'photoUrl': data['photoUrl'],
        };
      }
    } catch (e) {
      print("Kullanıcı detayı ($userId) alınırken hata: $e");
    }
    return {'name': 'Kullanıcı', 'photoUrl': null};
  }

  // Yeni sohbet başlatma veya var olana gitme fonksiyonu
  Future<void> _navigateToChat(
      BuildContext context, String recipientId, String recipientName) async {
    if (_currentUser == null) return;
    final currentUserId = _currentUser!.uid;

    // İki kullanıcı ID'sini her zaman aynı sırada tutarak (örn. küçük olan önce)
    // benzersiz bir chat ID oluşturmaya yardımcı olur.
    List<String> participantsArray = [currentUserId, recipientId]..sort();
    // String potentialChatId = participantsArray.join('_'); // Bu bir yöntem olabilir veya Firestore'a sorgu atılabilir

    // Önce var olan bir sohbeti ara
    QuerySnapshot existingChatSnapshot = await _firestore
        .collection('private_chats')
        .where('participants', whereIn: [
          [currentUserId, recipientId],
          [recipientId, currentUserId] // Her iki sıralamayı da kontrol et
        ])
        // .where('participants', arrayContainsAll: [currentUserId, recipientId]) // Bu daha iyi olabilir ama tam eşleşme için ek kontrol gerekebilir
        .limit(1)
        .get();

    String? chatIdToUse;
    if (existingChatSnapshot.docs.isNotEmpty) {
      // Var olan sohbeti bulmak için daha kesin bir filtreleme yapılmalı,
      // çünkü whereIn iki farklı array için de sonuç getirebilir.
      // Örneğin, [A,B] ve [B,A] için. Ya da participants array'i her zaman sıralı tutulmalı.
      // Şimdilik ilk bulduğunu alıyoruz ama bu iyileştirilmeli.
      for (var doc in existingChatSnapshot.docs) {
        final List<dynamic> p = doc['participants'];
        if (p.contains(currentUserId) &&
            p.contains(recipientId) &&
            p.length == 2) {
          chatIdToUse = doc.id;
          break;
        }
      }
      print("Var olan sohbet bulundu: $chatIdToUse");
    } else {
      print("Var olan sohbet bulunamadı, SohbetEkrani'nda yeni oluşturulacak.");
      // chatIdToUse null kalacak, SohbetEkrani bunu anlayıp yeni sohbet oluşturabilir.
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SohbetEkrani(
          chatId: chatIdToUse, // Var sa kullanılır, yoksa null
          mevcutKullaniciId: currentUserId,
          benOgretmenMiyim: widget
              .isTeacher, // Bu parametre SohbetEkrani için hala gerekli mi?
          recipientId: recipientId,
          recipientName: recipientName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlar'),
        backgroundColor: Colors.deepPurple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      )))
              : _currentUser == null
                  ? const Center(
                      child:
                          Text("Kullanıcıları görmek için giriş yapmalısınız."))
                  : RefreshIndicator(
                      onRefresh: _loadUsersForChatting, // Fonksiyon adı değişti
                      child: CustomScrollView(
                        slivers: <Widget>[
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.group_work,
                                        color: Colors.white),
                                    backgroundColor: Colors.blueAccent,
                                  ),
                                  title: const Text('Sınıf Sohbeti',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle:
                                      const Text("Okul genel sınıf sohbeti"),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => GrupSohbetSayfasi(
                                            isTeacher: widget.isTeacher),
                                      ),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0, vertical: 12.0),
                                  child: Text(
                                    widget.isTeacher
                                        ? "Velilerle Özel Mesaj Başlatın"
                                        : "Öğretmenlerle Özel Mesaj Başlatın",
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple[700]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _usersForChattingList.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        widget.isTeacher
                                            ? 'Sistemde veli bulunmuyor.'
                                            : 'Sistemde öğretmen bulunmuyor.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600]),
                                      ),
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (BuildContext context, int index) {
                                      DocumentSnapshot userDoc =
                                          _usersForChattingList[index];
                                      Map<String, dynamic> userData = userDoc
                                          .data() as Map<String, dynamic>;

                                      String userName =
                                          userData['displayName'] ??
                                              'Bilinmeyen Kullanıcı';
                                      String? photoUrl = userData['photoUrl'];
                                      String userId = userDoc.id;

                                      // _getUserDetails'ı burada çağırmaya gerek yok, userData zaten gerekli bilgileri içeriyor.
                                      // Ancak isterseniz daha fazla detay için çağırabilirsiniz.

                                      return Column(
                                        children: [
                                          ListTile(
                                            leading: CircleAvatar(
                                              backgroundImage: photoUrl != null
                                                  ? NetworkImage(photoUrl)
                                                  : null,
                                              child: photoUrl == null
                                                  ? Text(userName.isNotEmpty
                                                      ? userName[0]
                                                          .toUpperCase()
                                                      : "?")
                                                  : null,
                                            ),
                                            title: Text(userName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500)),
                                            // subtitle: Text(userData['email'] ?? ''), // İsteğe bağlı olarak e-posta vb. eklenebilir
                                            trailing: const Icon(
                                                Icons.chat_bubble_outline,
                                                size: 20),
                                            onTap: () {
                                              _navigateToChat(
                                                  context, userId, userName);
                                            },
                                          ),
                                          const Divider(
                                              height: 1,
                                              indent: 70,
                                              endIndent: 16),
                                        ],
                                      );
                                    },
                                    childCount: _usersForChattingList.length,
                                  ),
                                ),
                        ],
                      ),
                    ),
    );
  }
}

// Önceki _MesajlarSayfasiState ve ilgili Firestore yükleme kodları şimdilik kaldırıldı.
// Bu mantık, "Özel Mesajlar" seçeneği için ayrı bir sayfaya veya bu sayfanın state'ine
// geri eklenecek veya yeniden yapılandırılacak.
