import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting

// Dummy data for students - replace with actual data fetching
// const List<Map<String, String>> _dummyStudents = [
//   {'id': 'student1', 'name': 'Ahmet Yılmaz'},
//   {'id': 'student2', 'name': 'Ayşe Kaya'},
//   {'id': 'student3', 'name': 'Mehmet Demir'},
// ];

// Dummy meal definitions - this should ideally come from a daily menu service
// final Map<String, List<String>> _dummyMealMenu = {
//   'Öğün 1 (Kahvaltı)': [
//     'Omlet',
//     'Peynir',
//     'Zeytin',
//     'Domates',
//     'Salatalık',
//     'Bal',
//     'Süt'
//   ],
//   'Öğün 2 (Öğle Yemeği)': [
//     'Mercimek Çorbası',
//     'Tavuklu Pilav',
//     'Salata',
//     'Yoğurt'
//   ],
//   'Öğün 3 (İkindi)': ['Elmalı Kurabiye', 'Meyve Tabağı', 'Süt'],
// };

// Enum for food consumption status
enum FoodStatus { yedi, azYedi, yemedi, bilinmiyor }

class OgrenciDurumDegerlendirmeSayfasi extends StatefulWidget {
  final String currentUserId; // Teacher's ID or Parent's ID
  final bool isTeacherView;
  final String?
      initialStudentId; // For teachers, the starting student. For parents, their child's ID.

  const OgrenciDurumDegerlendirmeSayfasi({
    Key? key,
    required this.currentUserId,
    required this.isTeacherView,
    this.initialStudentId,
  }) : super(key: key);

  @override
  _OgrenciDurumDegerlendirmeSayfasiState createState() =>
      _OgrenciDurumDegerlendirmeSayfasiState();
}

class _OgrenciDurumDegerlendirmeSayfasiState
    extends State<OgrenciDurumDegerlendirmeSayfasi> {
  late List<Map<String, String>> _studentsToDisplay;
  late String _currentStudentId;
  late String _currentStudentName;
  int _currentStudentIndex = 0;

  DateTime _selectedDate = DateTime.now();
  Map<String, List<String>> _dailyMenu = {}; // Load dynamically later

  // Evaluation data
  String? _attendanceStatus; // 'geldi', 'gelmedi', 'izinli'
  String? _sleepStatus; // 'uyudu', 'uyumadi', 'az_uyudu'
  Map<String, Map<String, FoodStatus>> _mealEvaluations = {};
  String? _teacherNotes;
  late TextEditingController _notesController;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _initializePage();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _initializePage() async {
    setState(() => _isLoading = true);
    if (widget.isTeacherView) {
      try {
        QuerySnapshot studentSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('userRole', isEqualTo: 'ogrenci')
            .orderBy('displayName')
            .get();

        print("--- Öğrenci Sorgu Başlangıcı (userRole == ogrenci) ---");
        print(
            "Öğrenci sorgu sonucu: ${studentSnapshot.docs.length} belge bulundu.");
        if (studentSnapshot.docs.isEmpty) {
          print(
              "users koleksiyonunda 'userRole: ogrenci' koşulunu sağlayan belge bulunamadı.");
        } else {
          studentSnapshot.docs.forEach((doc) {
            print("Bulunan kullanıcı: ID: ${doc.id}, Data: ${doc.data()}");
          });
        }
        print("--- Öğrenci Sorgu Sonu ---");

        _studentsToDisplay = studentSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['displayName'] as String? ?? 'İsimsiz Öğrenci'
          };
        }).toList();

        if (_studentsToDisplay.isNotEmpty) {
          if (widget.initialStudentId != null) {
            _currentStudentIndex = _studentsToDisplay
                .indexWhere((s) => s['id'] == widget.initialStudentId);
            if (_currentStudentIndex == -1) {
              print(
                  "Başlangıç öğrenci ID'si (${widget.initialStudentId}) listede bulunamadı, ilk öğrenci seçiliyor.");
              _currentStudentIndex = 0;
            }
          } else {
            _currentStudentIndex = 0;
          }
          _currentStudentId = _studentsToDisplay[_currentStudentIndex]['id']!;
          _currentStudentName =
              _studentsToDisplay[_currentStudentIndex]['name']!;
        } else {
          _currentStudentId = '';
          _currentStudentName = 'Sistemde Öğrenci Yok';
          print(
              "Öğretmen görünümü: Sistemde 'userRole: ogrenci' olan öğrenci bulunamadı.");
        }
      } catch (e, s) {
        print("Öğrenci listesi yüklenirken hata: $e");
        print("Hata StackTrace: $s");
        _studentsToDisplay = [];
        _currentStudentId = '';
        _currentStudentName = 'Öğrenciler Yüklenemedi';
        // Hata durumunda kullanıcıya bir mesaj gösterilebilir.
      }
    } else {
      // Parent view: Load their specific child's data
      if (widget.initialStudentId == null) {
        print("HATA: Veli görünümü için öğrenci ID'si sağlanmadı.");
        _studentsToDisplay = [];
        _currentStudentId = '';
        _currentStudentName = 'Öğrenci Bilgisi Yok';
        setState(() => _isLoading = false);
        return;
      }
      _currentStudentId = widget.initialStudentId!;
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentStudentId)
            .get();
        if (userDoc.exists) {
          _currentStudentName =
              (userDoc.data() as Map<String, dynamic>)['displayName'] ??
                  'Öğrenci';
        } else {
          _currentStudentName = 'Öğrenci Bilgisi Yok (DB)';
        }
      } catch (e) {
        print("Öğrenci adı yüklenirken hata: $e");
        _currentStudentName = 'Öğrenci Bilgisi Hatalı';
      }
      _studentsToDisplay = [
        {'id': _currentStudentId, 'name': _currentStudentName}
      ];
      _currentStudentIndex = 0;
    }

    // Daily menu could also be loaded based on date if it changes
    await _loadMealListForDate(_selectedDate);

    await _loadEvaluationData();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMealListForDate(DateTime date) async {
    // Function body as defined previously
    print("Yemek listesi yükleniyor: Tarih: $date");
    setState(() {
      _dailyMenu = {};
    });

    try {
      final targetDateStart = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, 0, 0, 0));
      final targetDateEnd = Timestamp.fromDate(
          DateTime(date.year, date.month, date.day, 23, 59, 59));

      QuerySnapshot mealListSnapshot = await FirebaseFirestore.instance
          .collection('kullanici_yemek_listeleri')
          .where('date', isGreaterThanOrEqualTo: targetDateStart)
          .where('date', isLessThanOrEqualTo: targetDateEnd)
          .limit(1)
          .get();

      if (mealListSnapshot.docs.isNotEmpty) {
        final mealListData =
            mealListSnapshot.docs.first.data() as Map<String, dynamic>;
        if (mealListData.containsKey('ogunler') &&
            mealListData['ogunler'] is Map) {
          final Map<String, dynamic> ogunlerFromDb =
              mealListData['ogunler'] as Map<String, dynamic>;
          final Map<String, List<String>> loadedMenu = {};
          ogunlerFromDb.forEach((key, value) {
            if (value is List) {
              loadedMenu[key] =
                  List<String>.from(value.map((item) => item.toString()));
            }
          });
          setState(() {
            _dailyMenu = loadedMenu;
          });
          print("Yemek listesi başarıyla yüklendi: $_dailyMenu");
        } else {
          print(
              "Yemek listesi bulundu ancak 'ogunler' alanı beklenen formatta değil.");
          setState(() {
            _dailyMenu = {};
          });
        }
      } else {
        print("Seçili tarih için yemek listesi bulunamadı.");
        setState(() {
          _dailyMenu = {};
        });
      }
    } catch (e) {
      print("Yemek listesi yüklenirken hata: $e");
      setState(() {
        _dailyMenu = {};
      });
    }
  }

  String _getEvaluationDocId(String studentId, DateTime date) {
    return '${studentId}_${DateFormat('yyyy-MM-dd').format(date)}';
  }

  Future<void> _loadEvaluationData() async {
    if (_currentStudentId.isEmpty) {
      // Reset to defaults if no student is selected
      setState(() {
        _attendanceStatus = null;
        _sleepStatus = null;
        _mealEvaluations = {};
        _dailyMenu.forEach((mealName, items) {
          _mealEvaluations[mealName] = {};
          for (var item in items) {
            _mealEvaluations[mealName]![item] = FoodStatus.bilinmiyor;
          }
        });
        _notesController.text = ''; // Clear notes
      });
      return;
    }

    print(
        "Değerlendirme verisi yükleniyor: Öğrenci ID: $_currentStudentId, Tarih: $_selectedDate");
    setState(() {
      // Reset before loading new data
      _attendanceStatus = null;
      _sleepStatus = null;
      _mealEvaluations = {};
      _dailyMenu.forEach((mealName, items) {
        _mealEvaluations[mealName] = {};
        for (var item in items) {
          _mealEvaluations[mealName]![item] = FoodStatus.bilinmiyor;
        }
      });
      _notesController.text = ''; // Clear notes
    });

    final String docId = _getEvaluationDocId(_currentStudentId, _selectedDate);

    try {
      DocumentSnapshot evalDoc = await FirebaseFirestore.instance
          .collection('daily_evaluations')
          .doc(docId)
          .get();

      if (evalDoc.exists) {
        final data = evalDoc.data() as Map<String, dynamic>;
        setState(() {
          _attendanceStatus = data['attendance'];
          _sleepStatus = data['sleep'];
          _teacherNotes = data['teacherNotes'] as String?;
          _notesController.text = _teacherNotes ?? '';

          if (data['mealEvaluations'] != null) {
            final Map<String, dynamic> mealsFromDb =
                data['mealEvaluations'] as Map<String, dynamic>;
            _mealEvaluations = {}; // Ensure it's reset before filling

            _dailyMenu.forEach((mealName, foodItems) {
              _mealEvaluations[mealName] =
                  {}; // Initialize for each meal in the current menu
              if (mealsFromDb.containsKey(mealName)) {
                final Map<String, dynamic> itemsFromDb =
                    mealsFromDb[mealName] as Map<String, dynamic>;
                for (var foodItem in foodItems) {
                  // Iterate current menu items
                  if (itemsFromDb.containsKey(foodItem)) {
                    String statusStr = itemsFromDb[foodItem] as String;
                    _mealEvaluations[mealName]![foodItem] = FoodStatus.values
                        .firstWhere(
                            (e) => e.toString().split('.').last == statusStr,
                            orElse: () => FoodStatus.bilinmiyor);
                  } else {
                    _mealEvaluations[mealName]![foodItem] =
                        FoodStatus.bilinmiyor; // If not in DB for this menu
                  }
                }
              } else {
                // Meal name not in DB, set all items to bilinmiyor for current menu
                for (var foodItem in foodItems) {
                  _mealEvaluations[mealName]![foodItem] = FoodStatus.bilinmiyor;
                }
              }
            });
          }
          // Load teacher notes if available
          // _teacherNotes = data['teacherNotes'];
        });
        print("Değerlendirme verisi yüklendi: $docId");
      } else {
        print(
            "Değerlendirme belgesi bulunamadı: $docId. Varsayılanlar kullanılacak.");
        // Defaults are already set, so nothing more to do here for state.
      }
    } catch (e) {
      print("Değerlendirme verisi yüklenirken hata ($docId): $e");
      // Optionally show an error to the user
    }
  }

  Future<void> _saveEvaluationData() async {
    if (!widget.isTeacherView || _currentStudentId.isEmpty) {
      print(
          "Kaydetme atlandı: Öğretmen görünümü değil veya öğrenci seçilmedi.");
      return;
    }

    final String docId = _getEvaluationDocId(_currentStudentId, _selectedDate);
    print(
        "Değerlendirme verisi kaydediliyor: Öğrenci ID: $_currentStudentId, Tarih: $_selectedDate, DocID: $docId");

    // Prepare meal evaluations for Firestore (convert enum to string)
    Map<String, Map<String, String>> mealEvaluationsForDb = {};
    _mealEvaluations.forEach((mealName, items) {
      mealEvaluationsForDb[mealName] = {};
      items.forEach((foodItem, status) {
        mealEvaluationsForDb[mealName]![foodItem] =
            status.toString().split('.').last;
      });
    });

    try {
      await FirebaseFirestore.instance
          .collection('daily_evaluations')
          .doc(docId)
          .set({
        'studentId': _currentStudentId,
        'studentName':
            _currentStudentName, // Store student name for easier queries/display
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'evaluatorId': widget.currentUserId, // Teacher who made the evaluation
        'lastUpdated': FieldValue.serverTimestamp(),
        'attendance': _attendanceStatus,
        'sleep': _sleepStatus,
        'mealEvaluations': mealEvaluationsForDb,
        'teacherNotes': _notesController.text.trim(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Değerlendirme başarıyla kaydedildi!')));
      print("Değerlendirme kaydedildi: $docId");
    } catch (e) {
      print("Değerlendirme kaydedilirken hata ($docId): $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Değerlendirme kaydedilirken bir hata oluştu.')));
    }
  }

  void _changeStudent(int direction) {
    if (!widget.isTeacherView || _studentsToDisplay.length <= 1) return;

    // İlk setState: Senkron değişiklikler ve yükleme durumunu başlatma
    setState(() {
      _isLoading = true;
      _currentStudentIndex =
          (_currentStudentIndex + direction) % _studentsToDisplay.length;
      if (_currentStudentIndex < 0) {
        _currentStudentIndex = _studentsToDisplay.length - 1;
      }
      _currentStudentId = _studentsToDisplay[_currentStudentIndex]['id']!;
      _currentStudentName = _studentsToDisplay[_currentStudentIndex]['name']!;
    });

    // Asenkron işlemler setState dışında
    Future.microtask(() async {
      await _loadMealListForDate(_selectedDate);
      await _loadEvaluationData();
      // İkinci setState: Yükleme tamamlandıktan sonra arayüzü güncelle
      if (mounted) {
        // Widget hala ağaçtaysa setState çağır
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      // İlk setState: Senkron değişiklikler ve yükleme durumunu başlatma
      setState(() {
        _isLoading = true;
        _selectedDate = picked;
      });

      // Asenkron işlemler setState dışında
      // Future.microtask tercih edilebilir veya doğrudan await de kullanılabilir
      // eğer bu fonksiyonun kendisi zaten bir event handler (onPressed gibi) içindeyse.
      await _loadMealListForDate(_selectedDate);
      await _loadEvaluationData();
      // İkinci setState: Yükleme tamamlandıktan sonra arayüzü güncelle
      if (mounted) {
        // Widget hala ağaçtaysa setState çağır
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildStudentNavigator() {
    if (!widget.isTeacherView || _studentsToDisplay.length <= 1) {
      return Text(_currentStudentName,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => _changeStudent(-1)),
        Expanded(
          child: Center(
            child: Text(_currentStudentName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(
            icon: const Icon(Icons.arrow_forward_ios),
            onPressed: () => _changeStudent(1)),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            "Tarih: ${DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_selectedDate)}",
            style: const TextStyle(fontSize: 16)),
        IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _selectDate(context),
        ),
      ],
    );
  }

  // Helper to build a section title
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(title,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple)),
    );
  }

  // Placeholder for Attendance Section
  Widget _buildAttendanceSection() {
    if (!widget.isTeacherView && _attendanceStatus == null) {
      return const ListTile(
        title: Text("Devamsızlık"),
        trailing: Text("Değerlendirilmedi",
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
      );
    }
    if (!widget.isTeacherView) {
      return ListTile(
        title: const Text("Devamsızlık"),
        trailing: Text(
            _attendanceStatus?.replaceAll('_', ' ').replaceFirstMapped(
                    RegExp(r'\w'), (match) => match.group(0)!.toUpperCase()) ??
                "Belirtilmemiş",
            style: const TextStyle(fontSize: 16)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Devamsızlık"),
        RadioListTile<String>(
          title: const Text('Geldi'),
          value: 'geldi',
          groupValue: _attendanceStatus,
          onChanged: (String? value) {
            setState(() => _attendanceStatus = value);
            _saveEvaluationData();
          },
        ),
        RadioListTile<String>(
          title: const Text('Gelmedi'),
          value: 'gelmedi',
          groupValue: _attendanceStatus,
          onChanged: (String? value) {
            setState(() => _attendanceStatus = value);
            _saveEvaluationData();
          },
        ),
        RadioListTile<String>(
          title: const Text('İzinli'),
          value: 'izinli',
          groupValue: _attendanceStatus,
          onChanged: (String? value) {
            setState(() => _attendanceStatus = value);
            _saveEvaluationData();
          },
        ),
      ],
    );
  }

  // Placeholder for Sleep Section
  Widget _buildSleepSection() {
    if (!widget.isTeacherView && _sleepStatus == null) {
      return const ListTile(
        title: Text("Uyku Durumu"),
        trailing: Text("Değerlendirilmedi",
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
      );
    }
    if (!widget.isTeacherView) {
      return ListTile(
        title: const Text("Uyku Durumu"),
        trailing: Text(
            _sleepStatus?.replaceAll('_', ' ').replaceFirstMapped(
                    RegExp(r'\w'), (match) => match.group(0)!.toUpperCase()) ??
                "Belirtilmemiş",
            style: const TextStyle(fontSize: 16)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Uyku Durumu"),
        RadioListTile<String>(
          title: const Text('Uyudu'),
          value: 'uyudu',
          groupValue: _sleepStatus,
          onChanged: (String? value) {
            setState(() => _sleepStatus = value);
            _saveEvaluationData();
          },
        ),
        RadioListTile<String>(
          title: const Text('Uyumadı'),
          value: 'uyumadi',
          groupValue: _sleepStatus,
          onChanged: (String? value) {
            setState(() => _sleepStatus = value);
            _saveEvaluationData();
          },
        ),
        RadioListTile<String>(
          title: const Text('Az Uyudu'),
          value: 'az_uyudu',
          groupValue: _sleepStatus,
          onChanged: (String? value) {
            setState(() => _sleepStatus = value);
            _saveEvaluationData();
          },
        ),
      ],
    );
  }

  // Placeholder for Meals Section
  Widget _buildMealsSection() {
    if (_dailyMenu.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            "Seçili tarih için yemek listesi bulunmuyor.",
            style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _dailyMenu.entries.map((mealEntry) {
        String mealName = mealEntry.key;
        List<String> foodItems = mealEntry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(mealName),
            ...foodItems.map((foodItem) {
              FoodStatus status = _mealEvaluations[mealName]?[foodItem] ??
                  FoodStatus.bilinmiyor;
              if (!widget.isTeacherView) {
                return ListTile(
                  title: Text(foodItem),
                  trailing: Text(
                      status == FoodStatus.bilinmiyor
                          ? "Değerlendirilmedi"
                          : status
                              .toString()
                              .split('.')
                              .last
                              .replaceFirstMapped(RegExp(r'\w'),
                                  (match) => match.group(0)!.toUpperCase()),
                      style: TextStyle(
                          fontSize: 16,
                          fontStyle: status == FoodStatus.bilinmiyor
                              ? FontStyle.italic
                              : FontStyle.normal)),
                );
              }
              // Teacher's editable view
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(foodItem,
                            style: const TextStyle(fontSize: 16))),
                    // Example: Using choice chips or toggle buttons
                    ToggleButtons(
                      isSelected: [
                        _mealEvaluations[mealName]?[foodItem] ==
                            FoodStatus.yedi,
                        _mealEvaluations[mealName]?[foodItem] ==
                            FoodStatus.azYedi,
                        _mealEvaluations[mealName]?[foodItem] ==
                            FoodStatus.yemedi,
                      ],
                      onPressed: (int index) {
                        setState(() {
                          FoodStatus newStatus;
                          switch (index) {
                            case 0:
                              newStatus = FoodStatus.yedi;
                              break;
                            case 1:
                              newStatus = FoodStatus.azYedi;
                              break;
                            case 2:
                              newStatus = FoodStatus.yemedi;
                              break;
                            default:
                              newStatus = FoodStatus.bilinmiyor;
                          }
                          // Allow toggling off by pressing the same button again
                          if (_mealEvaluations[mealName]?[foodItem] ==
                              newStatus) {
                            _mealEvaluations[mealName]![foodItem] =
                                FoodStatus.bilinmiyor;
                          } else {
                            _mealEvaluations[mealName]![foodItem] = newStatus;
                          }
                          _saveEvaluationData();
                        });
                      },
                      children: const <Widget>[
                        Tooltip(
                            message: "Yedi",
                            child:
                                Icon(Icons.check_circle, color: Colors.green)),
                        Tooltip(
                            message: "Az Yedi",
                            child: Icon(Icons.check_circle_outline,
                                color: Colors.orange)),
                        Tooltip(
                            message: "Yemedi",
                            child: Icon(Icons.cancel, color: Colors.red)),
                      ],
                    )
                  ],
                ),
              );
            }).toList(),
            const Divider(),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTeacherNotesSection() {
    if (widget.isTeacherView) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Öğretmen Notları"),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    "Öğrenciyle ilgili genel notlarınızı buraya yazabilirsiniz...",
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                // Otomatik kaydetme istenirse burada _saveEvaluationData çağrılabilir
                // veya kaydet butonuna basıldığında alınır.
                // Şimdilik kaydet butonuna bırakıyoruz.
              },
            ),
          ],
        ),
      );
    } else {
      // Veli görünümü - sadece notları göster
      if (_teacherNotes == null || _teacherNotes!.trim().isEmpty) {
        return const ListTile(
          title: Text("Öğretmen Notu"),
          subtitle: Text("Eklenmiş bir not bulunmuyor.",
              style: TextStyle(fontStyle: FontStyle.italic)),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Öğretmen Notları"),
            Container(
                padding: const EdgeInsets.all(12.0),
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey[300]!)),
                child: Text(_teacherNotes!)),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.isTeacherView ? 'Günlük Değerlendirme' : 'Çocuğumun Durumu'),
        actions: [
          if (widget.isTeacherView)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveEvaluationData,
              tooltip: "Değerlendirmeyi Kaydet",
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentStudentId.isEmpty && widget.isTeacherView
              ? const Center(
                  child: Text("Değerlendirilecek öğrenci bulunamadı."))
              : _currentStudentId.isEmpty && !widget.isTeacherView
                  ? const Center(child: Text("Öğrenci bilgisi yüklenemedi."))
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => _isLoading = true);
                        // When refreshing, also reload the meal list for the current date
                        await _loadMealListForDate(_selectedDate);
                        await _loadEvaluationData();
                        setState(() => _isLoading = false);
                      },
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildStudentNavigator(),
                            const SizedBox(height: 8),
                            _buildDateSelector(),
                            const SizedBox(height: 16),
                            const Divider(thickness: 1),
                            _buildAttendanceSection(),
                            const Divider(thickness: 1),
                            _buildSleepSection(),
                            const Divider(thickness: 1),
                            _buildMealsSection(),
                            const Divider(thickness: 1),
                            _buildTeacherNotesSection(),
                            const SizedBox(height: 20),
                            if (widget.isTeacherView)
                              Center(
                                child: ElevatedButton(
                                  onPressed: _saveEvaluationData,
                                  child: const Text('Değerlendirmeyi Kaydet'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}
