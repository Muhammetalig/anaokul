import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Geri eklendi
// import 'dart:async'; // StreamSubscription kaldırıldığı için gereksiz olabilir
import 'giris.dart';
// import 'ogrencidurumu.dart'; // Eski sayfa importu kaldırıldı/yorumlandı
import 'ogrenci_durum_degerlendirme_sayfasi.dart'; // Yeni değerlendirme sayfası importu
import 'duyurular.dart'; // Yeni sayfa importu
import 'mesajlar.dart'; // MESAJLAR SAYFASI İÇİN YENİ İMPORT
import 'yemek_listesi_yonetim_sayfasi.dart'; // Import for meal list management

class Anasayfa extends StatefulWidget {
  final bool isTeacher;
  const Anasayfa({Key? key, required this.isTeacher}) : super(key: key);

  @override
  State<Anasayfa> createState() => _AnasayfaState();
}

class _AnasayfaState extends State<Anasayfa> {
  // StreamSubscription? _notificationSubscription; // Kaldırıldı
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    // Bildirim dinleyicisi ile ilgili kod kaldırıldı
  }

  // _listenForNotifications fonksiyonu tamamen kaldırıldı

  Future<void> _cikisYap(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GirisEkrani()),
          (route) => false, // Tüm önceki route'ları kaldır
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Çıkış sırasında hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // _notificationSubscription?.cancel(); // Kaldırıldı
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isTeacher ? 'Öğretmen Paneli' : 'Veli Paneli'),
        backgroundColor: Colors.teal, // Ana sayfa için farklı bir AppBar rengi
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _cikisYap(context),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Butonların genişlemesi için
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Öğrenci Durumu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors
                      .blue, // Renkler ogrencidurumu sayfasıyla uyumlu olabilir
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (_currentUser == null) return;

                  if (widget.isTeacher) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OgrenciDurumDegerlendirmeSayfasi(
                          currentUserId: _currentUser!.uid,
                          isTeacherView: true,
                          // initialStudentId: null, // Öğretmen ilk öğrenciyi kendi seçebilir veya sayfa ilkini yükler
                        ),
                      ),
                    );
                  } else {
                    // Veli ise, çocuğunun ID'sini Firestore'dan al
                    try {
                      DocumentSnapshot userDoc = await FirebaseFirestore
                          .instance
                          .collection('users')
                          .doc(_currentUser!.uid)
                          .get();
                      if (userDoc.exists && userDoc.data() != null) {
                        final data = userDoc.data() as Map<String, dynamic>;
                        final List<dynamic>? childrenIds =
                            data['children'] as List<dynamic>?;

                        if (childrenIds != null && childrenIds.isNotEmpty) {
                          // Şimdilik ilk çocuğu alıyoruz
                          final String childId = childrenIds.first as String;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OgrenciDurumDegerlendirmeSayfasi(
                                currentUserId: _currentUser!.uid,
                                isTeacherView: false,
                                initialStudentId: childId,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Size atanmış bir öğrenci bulunamadı.')),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Veli bilgileri bulunamadı.')),
                        );
                      }
                    } catch (e) {
                      print("Çocuk ID'si alınırken hata: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Öğrenci bilgileri alınırken bir sorun oluştu.')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Duyurular'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.orange, // Renkler duyurular sayfasıyla uyumlu
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DuyurularSayfasi(isTeacher: widget.isTeacher),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24), // Butonlar arası boşluk
              ElevatedButton.icon(
                icon: const Icon(Icons.message_outlined), // Mesajlar için ikon
                label: const Text('Mesajlar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.deepPurple, // Mesajlar sayfasıyla uyumlu bir renk
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MesajlarSayfasi(isTeacher: widget.isTeacher),
                    ),
                  );
                },
              ),
              // Add the Meal List button for Parents
              if (!widget.isTeacher) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(
                      Icons.restaurant_menu), // Farklı bir ikon olabilir
                  label: const Text('Yemek Listesi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Farklı bir renk
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const YemekListesiYonetimSayfasi(isTeacher: false),
                      ),
                    );
                  },
                ),
              ],
              // Conditionally add the Meal List Management button for teachers
              if (widget.isTeacher) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.restaurant_menu_outlined),
                  label: const Text('Yemek Listelerini Yönet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple, // A distinct color
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const YemekListesiYonetimSayfasi(isTeacher: true),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ColorDisplayButton extends StatefulWidget {
  final bool isTeacher;
  final bool colorIsRed;
  final VoidCallback? onPressed;

  const ColorDisplayButton({
    Key? key,
    required this.isTeacher,
    required this.colorIsRed,
    this.onPressed,
  }) : super(key: key);

  @override
  State<ColorDisplayButton> createState() => _ColorDisplayButtonState();
}

class _ColorDisplayButtonState extends State<ColorDisplayButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.colorIsRed ? Colors.red : Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        disabledBackgroundColor: widget.colorIsRed ? Colors.red : Colors.green,
        disabledForegroundColor: Colors.white.withOpacity(0.7),
      ),
      child: Text(
        widget.isTeacher ? 'Renk Değiştir' : 'Mevcut Renk',
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    );
  }
}
