import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class YemekListesiDuzenlemeSayfasi extends StatefulWidget {
  final String? mealListId; // Null for new list, existing ID for editing
  final Map<String, dynamic>? initialData; // For editing existing list

  const YemekListesiDuzenlemeSayfasi(
      {Key? key, this.mealListId, this.initialData})
      : super(key: key);

  @override
  _YemekListesiDuzenlemeSayfasiState createState() =>
      _YemekListesiDuzenlemeSayfasiState();
}

class _YemekListesiDuzenlemeSayfasiState
    extends State<YemekListesiDuzenlemeSayfasi> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _listNameController;
  final Map<String, List<String>> _ogunlerVeYemekler = {};
  final Map<String, TextEditingController> _foodInputControllers = {};
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FocusNode _listNameFocusNode = FocusNode();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _listNameController = TextEditingController();
    _selectedDate = DateTime.now(); // Varsayılan olarak bugünün tarihini seç

    if (widget.mealListId != null && widget.initialData != null) {
      _listNameController.text = widget.initialData!['listName'] ?? '';
      // Tarihi Firestore'dan al
      if (widget.initialData!['date'] != null) {
        _selectedDate = (widget.initialData!['date'] as Timestamp).toDate();
      }
      final Map<String, dynamic>? ogunlerFromDb =
          widget.initialData!['ogunler'] as Map<String, dynamic>?;
      if (ogunlerFromDb != null) {
        _ogunlerVeYemekler.addAll(ogunlerFromDb.map(
          (key, value) =>
              MapEntry(key, List<String>.from(value as List<dynamic>? ?? [])),
        ));
        _ogunlerVeYemekler.keys.forEach((mealName) {
          _foodInputControllers[mealName] = TextEditingController();
        });
      }
    } else {
      _ogunlerVeYemekler['Kahvaltı'] = [];
      _foodInputControllers['Kahvaltı'] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _listNameFocusNode.dispose();
    for (var controller in _foodInputControllers.values) {
      controller.dispose();
    }
    _foodInputControllers.clear();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveMealList() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) {
      return;
    }
    if (_ogunlerVeYemekler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir öğün ekleyiniz.')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir tarih seçiniz.')),
      );
      return;
    }
    // Check if any meal has an empty food list
    bool anyMealIsEmpty =
        _ogunlerVeYemekler.values.any((foodList) => foodList.isEmpty);
    if (anyMealIsEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tüm öğünler en az bir yemek içermelidir.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final listData = {
      'teacherId': _currentUser!.uid,
      'listName': _listNameController.text.trim(),
      'date': Timestamp.fromDate(_selectedDate!),
      'ogunler': _ogunlerVeYemekler,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.mealListId != null) {
        await _firestore
            .collection('kullanici_yemek_listeleri')
            .doc(widget.mealListId)
            .update(listData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yemek listesi başarıyla güncellendi.')),
        );
      } else {
        await _firestore.collection('kullanici_yemek_listeleri').add(listData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yemek listesi başarıyla oluşturuldu.')),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      print("Yemek listesi kaydedilirken hata: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Yemek listesi kaydedilirken bir hata oluştu: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addMeal(String mealName) {
    if (mealName.trim().isEmpty) return;
    setState(() {
      _ogunlerVeYemekler[mealName.trim()] = [];
      if (!_foodInputControllers.containsKey(mealName.trim())) {
        _foodInputControllers[mealName.trim()] = TextEditingController();
      }
    });
  }

  void _deleteMeal(String mealName) {
    setState(() {
      _ogunlerVeYemekler.remove(mealName);
      _foodInputControllers[mealName]?.dispose();
      _foodInputControllers.remove(mealName);
    });
  }

  void _addFoodToMeal(String mealName, String foodItem) {
    if (foodItem.trim().isEmpty) return;
    setState(() {
      _ogunlerVeYemekler[mealName]?.add(foodItem.trim());
      _foodInputControllers[mealName]?.clear();
    });
  }

  void _deleteFoodFromMeal(String mealName, String foodItem) {
    setState(() {
      _ogunlerVeYemekler[mealName]?.remove(foodItem);
    });
  }

  Future<void> _showAddMealDialog() async {
    final TextEditingController mealNameController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    String? result;

    try {
      result = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: const Text('Yeni Öğün Ekle'),
              content: TextField(
                controller: mealNameController,
                focusNode: focusNode,
                autofocus: true,
                decoration:
                    const InputDecoration(hintText: "Öğün adı (örn: Ara Öğün)"),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop(value.trim());
                  }
                },
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('İptal'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Ekle'),
                  onPressed: () {
                    if (mealNameController.text.trim().isNotEmpty) {
                      Navigator.of(context).pop(mealNameController.text.trim());
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Öğün adı boş olamaz!")),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      );
    } finally {
      focusNode.dispose();
      mealNameController.dispose();
    }

    if (result != null && result.isNotEmpty) {
      if (_ogunlerVeYemekler.containsKey(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$result adlı öğün zaten mevcut.')),
          );
        }
      } else {
        _addMeal(result);
      }
    }
  }

  Widget _buildFoodInputField(
      String mealName, TextEditingController controller) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Bu öğüne yemek ekle...',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _addFoodToMeal(mealName, value);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ekle'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 14),
          ),
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              _addFoodToMeal(mealName, controller.text);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Yemek adı boş olamaz!")),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildOgunlerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Öğünler ve Yemekler',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_ogunlerVeYemekler.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                "Henüz öğün eklenmedi.",
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ..._ogunlerVeYemekler.entries.map((entry) {
          final String mealName = entry.key;
          final List<String> foodItems = entry.value;
          final TextEditingController currentFoodController =
              _foodInputControllers[mealName]!;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2.0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          mealName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'Bu Öğünü Sil',
                        onPressed: () => _deleteMeal(mealName),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (foodItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Bu öğün için henüz yemek eklenmemiş.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ...foodItems
                      .map((food) => ListTile(
                            title: Text(food),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                size: 20,
                                color: Colors.deepOrange,
                              ),
                              tooltip: '$food Yemeğini Sil',
                              onPressed: () =>
                                  _deleteFoodFromMeal(mealName, food),
                            ),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ))
                      .toList(),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child:
                        _buildFoodInputField(mealName, currentFoodController),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Yeni Öğün Ekle'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: _showAddMealDialog,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mealListId == null
            ? 'Yeni Yemek Listesi Oluştur'
            : 'Yemek Listesini Düzenle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveMealList,
            tooltip: 'Kaydet',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _listNameController,
                      focusNode: _listNameFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Liste Adı',
                        hintText: 'Örn: Haftalık Menü, Pazartesi Öğle Yemeği',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Liste adı boş bırakılamaz.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tarih',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Tarih Seçin',
                          style: TextStyle(
                            color: _selectedDate != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildOgunlerSection(),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Yemek Listesini Kaydet'),
                        onPressed: _isLoading ? null : _saveMealList,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
