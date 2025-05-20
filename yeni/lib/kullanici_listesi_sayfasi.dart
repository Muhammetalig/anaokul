import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sohbet_ekrani.dart'; // Bir sonraki adımda oluşturulacak

class KullaniciListesiSayfasi extends StatefulWidget {
  final bool isTeacher;

  const KullaniciListesiSayfasi({Key? key, required this.isTeacher})
      : super(key: key);

  @override
  State<KullaniciListesiSayfasi> createState() =>
      _KullaniciListesiSayfasiState();
}

class _KullaniciListesiSayfasiState extends State<KullaniciListesiSayfasi> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  List<Map<String, dynamic>> _kullanicilar = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _kullanicilariYukle();
  }

  Future<void> _kullanicilariYukle() async {
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot querySnapshot;
      if (widget.isTeacher) {
        // Öğretmen ise tüm velileri (isTeacher == false VE userRole == 'veli') yükle
        querySnapshot = await _firestore
            .collection('users')
            .where('isTeacher', isEqualTo: false)
            .where('userRole', isEqualTo: 'veli')
            .get();
      } else {
        // Veli ise tüm öğretmenleri (isTeacher == true) yükle
        querySnapshot = await _firestore
            .collection('users')
            .where('isTeacher', isEqualTo: true)
            .get();
      }

      List<Map<String, dynamic>> tempList = [];
      for (var doc in querySnapshot.docs) {
        if (doc.id == _currentUser!.uid) continue; // Kendi kendini listeleme

        var data = doc.data() as Map<String, dynamic>;
        tempList.add({
          'uid': doc.id,
          'displayName':
              data['displayName'] ?? doc.id, // displayName yoksa uid göster
          'email': data['email'] ?? 'E-posta Yok',
          // İleride gerekirse diğer kullanıcı bilgileri de eklenebilir
        });
      }
      setState(() {
        _kullanicilar = tempList;
        _isLoading = false;
      });
    } catch (e) {
      print("Kullanıcıları (özel mesaj için) yüklerken hata: $e");
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kişiler yüklenirken bir sorun oluştu: $e')),
        );
      }
    }
  }

  String _generateChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); // ID'leri sıralayarak her zaman aynı chat ID'sini oluştur
    return ids.join('_');
  }

  void _ozelSohbeteGit(Map<String, dynamic> digerKullanici) {
    if (_currentUser == null) return;

    final String otherUserId = digerKullanici['uid'];
    final String chatId = _generateChatId(_currentUser!.uid, otherUserId);
    final String otherUserName = digerKullanici['displayName'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SohbetEkrani(
          chatId: chatId,
          recipientId: otherUserId,
          recipientName: otherUserName,
          // currentUserIsTeacher: widget.isTeacher, // Sohbet ekranı bunu kendi alabilir veya _currentUserDoc'tan bakabilir
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTeacher
            ? 'Veliler (Özel Mesaj)'
            : 'Öğretmenler (Özel Mesaj)'),
        backgroundColor: Colors.greenAccent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _kullanicilar.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      widget.isTeacher
                          ? 'Özel mesaj gönderebileceğiniz veli bulunamadı.'
                          : 'Özel mesaj gönderebileceğiniz öğretmen bulunamadı.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _kullanicilar.length,
                  itemBuilder: (context, index) {
                    final kullanici = _kullanicilar[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            kullanici['displayName'] != null &&
                                    kullanici['displayName'].isNotEmpty
                                ? kullanici['displayName'][0].toUpperCase()
                                : '?',
                          ),
                        ),
                        title: Text(kullanici['displayName'] ?? 'İsim Yok'),
                        subtitle: Text(kullanici['email'] ?? 'E-posta Yok'),
                        onTap: () => _ozelSohbeteGit(kullanici),
                      ),
                    );
                  },
                ),
    );
  }
}
