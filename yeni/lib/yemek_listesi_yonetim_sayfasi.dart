import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'yemek_listesi_duzenleme_sayfasi.dart'; // Import the editing page

// TODO: Define a model class for MealList if it becomes complex

class YemekListesiYonetimSayfasi extends StatefulWidget {
  final bool isTeacher;

  const YemekListesiYonetimSayfasi({
    Key? key,
    required this.isTeacher,
  }) : super(key: key);

  @override
  _YemekListesiYonetimSayfasiState createState() =>
      _YemekListesiYonetimSayfasiState();
}

class _YemekListesiYonetimSayfasiState
    extends State<YemekListesiYonetimSayfasi> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Stream<QuerySnapshot>? _mealListsStream;

  @override
  void initState() {
    super.initState();
    if (_currentUser != null) {
      if (widget.isTeacher) {
        _mealListsStream = _firestore
            .collection('kullanici_yemek_listeleri')
            .where('teacherId', isEqualTo: _currentUser.uid)
            .orderBy('listName')
            .snapshots();
      } else {
        _mealListsStream = _firestore
            .collection('kullanici_yemek_listeleri')
            .orderBy('listName')
            .snapshots();
      }
    }
  }

  Future<void> _deleteMealList(String docId) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yemek Listesini Sil'),
          content: const Text(
              'Bu yemek listesini silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _firestore
            .collection('kullanici_yemek_listeleri')
            .doc(docId)
            .delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yemek listesi başarıyla silindi.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yemek listesi silinirken hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yemek Listeleri'),
        backgroundColor: Colors.indigo,
      ),
      body: _currentUser == null
          ? const Center(
              child: Text('Yemek listelerini görmek için giriş yapmalısınız.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _mealListsStream,
              builder: (context, snapshot) {
                print(
                    "StreamBuilder Connection State: ${snapshot.connectionState}");
                if (snapshot.hasData) {
                  print(
                      "StreamBuilder Has Data: True, Document Count: ${snapshot.data!.docs.length}");
                } else {
                  print("StreamBuilder Has Data: False");
                }
                if (snapshot.hasError) {
                  print(
                      "StreamBuilder Has Error: True, Error: ${snapshot.error}");
                  print("StreamBuilder StackTrace: ${snapshot.stackTrace}");
                } else {
                  print("StreamBuilder Has Error: False");
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  print("StreamBuilder: Waiting for data...");
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  print("StreamBuilder: Error occurred: ${snapshot.error}");
                  return Center(child: Text('Hata oluştu: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  print("StreamBuilder: No data or empty documents.");
                  return const Center(
                      child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Henüz yemek listesi bulunmuyor.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ));
                }

                final mealLists = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: mealLists.length,
                  itemBuilder: (context, index) {
                    final listDoc = mealLists[index];
                    final listData = listDoc.data() as Map<String, dynamic>;
                    final String listName =
                        listData['listName'] as String? ?? 'İsimsiz Liste';
                    final Map<String, dynamic> ogunler =
                        listData['ogunler'] as Map<String, dynamic>? ?? {};

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: ExpansionTile(
                        title: Text(listName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: ogunler.entries.map((entry) {
                                final String ogunAdi = entry.key;
                                final List<dynamic> yemekler =
                                    entry.value as List<dynamic>? ?? [];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(ogunAdi,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: Colors.indigo[700])),
                                      if (yemekler.isNotEmpty)
                                        ...yemekler.map((yemek) => Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0, top: 2.0),
                                              child: Text(
                                                  "- ${yemek as String? ?? 'Belirsiz yemek'}"),
                                            ))
                                      else
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              left: 8.0, top: 2.0),
                                          child: Text(
                                              "- Bu öğün için yemek eklenmemiş.",
                                              style: TextStyle(
                                                  fontStyle: FontStyle.italic)),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          if (widget.isTeacher)
                            ButtonBar(
                              alignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  label: const Text('Düzenle',
                                      style: TextStyle(color: Colors.blue)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            YemekListesiDuzenlemeSayfasi(
                                          mealListId: listDoc.id,
                                          initialData: listData,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  label: const Text('Sil',
                                      style: TextStyle(color: Colors.red)),
                                  onPressed: () => _deleteMealList(listDoc.id),
                                ),
                              ],
                            )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: widget.isTeacher
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Yeni Liste Ekle'),
              backgroundColor: Colors.indigo,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const YemekListesiDuzenlemeSayfasi(),
                  ),
                );
              },
            )
          : null,
    );
  }
}
