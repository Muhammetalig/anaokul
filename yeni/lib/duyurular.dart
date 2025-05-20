import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DuyurularSayfasi extends StatefulWidget {
  final bool isTeacher;

  const DuyurularSayfasi({Key? key, required this.isTeacher}) : super(key: key);

  @override
  State<DuyurularSayfasi> createState() => _DuyurularSayfasiState();
}

class _DuyurularSayfasiState extends State<DuyurularSayfasi> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _baslikController = TextEditingController();
  final TextEditingController _icerikController = TextEditingController();
  bool _isLoading = false;
  // FCM server key - güvenlik için gerçek uygulamada sunucu taraflı yapılmalı
  // final String serverKey =
  //     'AAAAQ5OxIb8:APA91bE1_zc7e5iohLDibbAR5d-vxPcl8l5J_5Vl2lsBZBXOyYLPW9pYlMQjDgUVwQ551rBxs1Qa0CiQOYE1tnDVpE5cJlkP0LmNVBzZB6PaSoZF_7SCT1iUTq1mLQS-2U_aEL-yC2gw';

  @override
  void dispose() {
    _baslikController.dispose();
    _icerikController.dispose();
    super.dispose();
  }

  // Duyuru ekleme fonksiyonu (Öğretmen için)
  Future<void> _duyuruEkle() async {
    final baslik = _baslikController.text.trim();
    final icerik = _icerikController.text.trim();

    if (baslik.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir başlık girin.')),
      );
      return;
    }

    if (icerik.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir duyuru içeriği girin.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı girişi yapılmamış.');
      }

      // Firebase Functions'ı tetiklemek için baslik ve icerik alanlarını ekledik
      DocumentReference duyuruRef =
          await _firestore.collection('notifications').add({
        'baslik': baslik, // Firebase Functions için gerekli alan
        'icerik': icerik, // Firebase Functions için gerekli alan
        'text': '$baslik: $icerik', // Eski alan için geriye dönük uyumluluk
        'createdAt': FieldValue.serverTimestamp(),
        'tarih':
            FieldValue.serverTimestamp(), // Firebase Functions için ek alan
        'olusturan': user.uid,
      });

      // Manuel olarak topic bildirimi gönder
      // await _sendTopicNotification(baslik, icerik, duyuruRef.id);

      _baslikController.clear();
      _icerikController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Duyuru başarıyla eklendi ve bildirim gönderildi.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Duyuru eklenirken hata oluştu: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Manuel olarak FCM topic bildirimi gönderme fonksiyonu
  /*
  Future<void> _sendTopicNotification(
      String baslik, String icerik, String duyuruId) async {
    try {
      print('🔄 Manuel bildirim gönderme başlatılıyor...');

      // Önce mevcut kullanıcının ID'sini al (öğretmenin ID'si)
      final String currentUserId = _auth.currentUser?.uid ?? '';
      print('👨‍🏫 Mevcut kullanıcı (öğretmen) ID: $currentUserId');

      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');

      // Bildirimin içeriği
      final bildirimIcerigi =
          icerik.length > 100 ? '${icerik.substring(0, 97)}...' : icerik;

      // Önce tokens alalım - güvenlik için normalde bu backend tarafında yapılmalı
      final tokenSnapshot = await _firestore
          .collection('users')
          .where('isTeacher', isEqualTo: false) // Sadece veliler
          .get();

      if (tokenSnapshot.docs.isEmpty) {
        print('⚠️ Bildirimi alacak veli kullanıcısı bulunamadı');
        return;
      }

      List<String> tokens = [];
      for (var doc in tokenSnapshot.docs) {
        final userData = doc.data();
        // Mevcut öğretmen kullanıcının kendi bildirim almasını engelle
        if (doc.id == currentUserId) {
          print('🚫 Mevcut öğretmen kullanıcısı bildirim almayacak: ${doc.id}');
          continue;
        }

        if (userData.containsKey('fcmToken') && userData['fcmToken'] != null) {
          tokens.add(userData['fcmToken']);
          print(
              '📱 Veli token bulundu: ${userData['fcmToken']} (Kullanıcı: ${doc.id})');
        }
      }

      if (tokens.isEmpty) {
        print('⚠️ Hiçbir geçerli FCM token bulunamadı');

        // Topic bildirimi deneyelim
        final topicBody = {
          'to': '/topics/announcements', // Topic adı
          'notification': {
            'title': 'Yeni Duyuru: $baslik',
            'body': bildirimIcerigi,
            'sound': 'default',
            'android_channel_id': 'yeni_duyurular',
          },
          'data': {
            'type': 'duyuru',
            'duyuruId': duyuruId,
            'duyuruBaslik': baslik,
            'duyuruIcerik': bildirimIcerigi,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK'
          },
          'priority': 'high',
        };

        print('📤 Topic bildirimi gönderiliyor...');
        print('📝 İçerik: ${json.encode(topicBody)}');

        final topicResponse = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            // 'Authorization': 'key=$serverKey',
          },
          body: json.encode(topicBody),
        );

        print(
            '📊 Topic yanıtı: ${topicResponse.statusCode} - ${topicResponse.body}');
        return;
      }

      print('🔢 Toplam ${tokens.length} token bulundu');

      // Her bir token için ayrı bildirim gönder
      for (var token in tokens) {
        // Single device message
        final body = {
          'to': token,
          'notification': {
            'title': 'Yeni Duyuru: $baslik',
            'body': bildirimIcerigi,
            'sound': 'default',
            'android_channel_id': 'yeni_duyurular',
          },
          'data': {
            'type': 'duyuru',
            'duyuruId': duyuruId,
            'duyuruBaslik': baslik,
            'duyuruIcerik': bildirimIcerigi,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'importance': 'max',
            'priority': 'high',
          },
          'priority': 'high',
          'contentAvailable': true,
        };

        print('📤 Bildirim gönderiliyor token: $token');
        print('📝 İçerik: ${json.encode(body)}');

        // HTTP isteği gönder
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            // 'Authorization': 'key=$serverKey',
          },
          body: json.encode(body),
        );

        print('📊 Bildirim yanıtı: ${response.statusCode} - ${response.body}');

        if (response.statusCode != 200) {
          print(
              '❌ Bildirim gönderme hatası: ${response.statusCode} - ${response.body}');
        } else {
          print('✅ Bildirim başarıyla gönderildi!');
        }
      }

      // Yerel bildirim de göster (FCM çalışmasa bile görünecek)
      // _showLocalNotification('Yeni Duyuru: $baslik', bildirimIcerigi);
    } catch (e) {
      print('❌ Bildirim gönderirken hata oluştu: $e');
      // Hata durumunda bile yerel bildirimi göstermeyi dene
      // _showLocalNotification('Yeni Duyuru', 'Yeni bir duyuru eklendi');
    }
  }
  */

  // Yerel bildirim gösterme fonksiyonu
  /*
  Future<void> _showLocalNotification(String title, String body) async {
    // Eğer bu kullanıcı bir öğretmense yerel bildirim gösterme
    // (zaten bildirimi kendisi oluşturuyor)
    if (widget.isTeacher) {
      print('🚫 Öğretmen kullanıcısına yerel bildirim gösterilmeyecek');
      return;
    }

    print('📲 Veli için yerel bildirim gösteriliyor: $title - $body');

    // Android için bildirim kanalı oluştur
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'yeni_duyurular', // ID
      'Yeni Duyurular', // Name
      channelDescription: 'Yeni Anaokulu duyuruları için bildirim kanalı',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    // iOS için bildirim detayları
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    // Genel bildirim detayları
    const NotificationDetails generalDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    // Yerel bildirim plugin'ine erişim
    FlutterLocalNotificationsPlugin localNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    try {
      await localNotificationsPlugin.show(
        DateTime.now().millisecond, // ID (unique)
        title,
        body,
        generalDetails,
      );
      print('✅ Veli için yerel bildirim başarıyla gösterildi');
    } catch (e) {
      print('❌ Yerel bildirim gösterilirken hata oluştu: $e');
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyurular'),
        backgroundColor: Colors.orange, // Farklı bir renk
      ),
      body: Column(
        children: [
          // Öğretmen ise duyuru giriş alanı göster
          if (widget.isTeacher)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _baslikController,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      hintText: 'Duyuru başlığını girin',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _icerikController,
                    decoration: const InputDecoration(
                      labelText: 'İçerik',
                      hintText: 'Duyuru içeriğini girin...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _duyuruEkle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send),
                    label: const Text('Duyuru Gönder ve Bildirimleri Tetikle'),
                  ),
                ],
              ),
            ),

          // Duyuruları listeleyen StreamBuilder
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .orderBy('createdAt',
                      descending: true) // En yeni duyuru üstte
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("Duyuru stream hatası: ${snapshot.error}");
                  return const Center(
                      child: Text('Duyurular yüklenirken bir hata oluştu.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Henüz duyuru yok.'));
                }

                final duyurular = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: duyurular.length,
                  itemBuilder: (context, index) {
                    final duyuru = duyurular[index];
                    final data = duyuru.data() as Map<String, dynamic>;

                    // Önce baslik ve icerik alanlarını kontrol et, yoksa text alanını kullan
                    final baslik = data['baslik'] as String? ?? '';
                    final icerik = data['icerik'] as String? ?? '';
                    final text = data['text'] as String? ?? '';

                    // Gösterilecek başlık ve içerik
                    final displayBaslik = baslik.isNotEmpty
                        ? baslik
                        : (text.contains(':')
                            ? text.split(':')[0].trim()
                            : 'Başlıksız');
                    final displayIcerik = icerik.isNotEmpty
                        ? icerik
                        : (text.contains(':') && text.split(':').length > 1
                            ? text.split(':').sublist(1).join(':').trim()
                            : text);

                    final timestamp = data['createdAt'] as Timestamp?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(
                          displayBaslik,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayIcerik),
                            const SizedBox(height: 4),
                            Text(
                              timestamp != null
                                  ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} ${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                                  : 'Tarih yok',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        // İsterseniz öğretmene silme butonu ekleyebilirsiniz
                        // trailing: widget.isTeacher ? IconButton(icon: Icon(Icons.delete), onPressed: () => _duyuruSil(duyuru.id)) : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Duyuru silme fonksiyonu (isteğe bağlı - öğretmen için)
  /*
  Future<void> _duyuruSil(String docId) async {
    try {
      await _firestore.collection('duyurular').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Duyuru silindi.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duyuru silinirken hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  */
}
