import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'giris.dart';
import 'anasayfa.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Flutter yerel bildirim eklentisi için global instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Android için bildirim kanalı ID
const String androidNotificationChannelId = 'yeni_duyurular';
const String androidNotificationChannelName = 'Yeni Duyurular';
const String androidNotificationChannelDescription =
    'Yeni Anaokulu duyuruları için bildirim kanalı';

// Uygulama kapalıyken gelen bildirimleri işlemek için (varsa) global handler
// Bu fonksiyonun sınıf dışında, en üst seviyede tanımlanması gerekir.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Eğer Firebase henüz başlatılmadıysa başlat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Arka plan mesajı işleniyor: ${message.messageId}");

  // Arka planda öğretmen kontrolü yap
  bool isTeacher = false; // Varsayılan olarak false
  try {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (docSnap.exists && docSnap.data()?['isTeacher'] == true) {
        isTeacher = true;
      }
    }
  } catch (e) {
    print(
        "Arka plan öğretmen kontrol hatası: $e - Bu beklenen bir durum olabilir.");
    // Arka planda kullanıcı oturumuna erişim her zaman mümkün olmayabilir.
  }

  if (isTeacher) {
    print(
        "👨‍🏫 Arka plan: Öğretmen kullanıcısı olduğu için bildirim işlenmeyecek.");
    return; // Öğretmen ise bildirim gösterme
  }

  print("Arka plan: Veli/genel kullanıcı, mesaj verisi işleniyor...");
  print("Arka plan mesaj başlığı: ${message.notification?.title}");
  print("Arka plan mesaj gövdesi: ${message.notification?.body}");
  print("Arka plan mesaj verisi: ${message.data}");

  // Eğer mesajda notification alanı varsa yerel bildirim göster
  if (message.notification != null) {
    showLocalNotification(
      message.notification?.title ?? 'Yeni Bildirim',
      message.notification?.body ?? 'Yeni bir bildiriminiz var.',
      payload: message.data.toString(), // Data varsa payload'a ekleyelim
    );
  } else {
    // Notification alanı yoksa, data alanı varsa ve buradan bildirim oluşturmak gerekirse burası düzenlenebilir.
    // Şimdilik sadece notification payload'u olanlar için bildirim gösteriyoruz.
    print(
        "ℹ️ Arka plan: Mesajda 'notification' alanı bulunmadığı için yerel bildirim gösterilmedi.");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase başarıyla başlatıldı');

    // Emülatör tespiti yap ve bildir
    final bool isEmulator = await _isRunningOnEmulator();
    print(isEmulator
        ? '🔴 Uygulama bir emülatörde çalışıyor, FCM çalışmayabilir'
        : '🟢 Uygulama fiziksel cihazda çalışıyor, FCM çalışmalı');

    // Arka plan bildirim işleyicisini başlatmadan önce ayarla
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // iOS için apple auto init
    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    // Bildirim kanallarını oluştur
    await _setupNotifications();

    // Bildirim izni iste
    await _initializeNotificationPermissions();

    // FCM token'ı konsola yazdır (debug için)
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('📱 FCM TOKEN: $fcmToken');

    // Ön planda bildirim göstermek için listener ekle
    _setupForegroundNotificationListener();

    // Token yenilendiğinde Firestore'u güncellemek için listener ekle
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 FCM Token yenilendi (onTokenRefresh): $newToken');
      _updateFcmTokenIfNecessary(newToken);
    });

    // Topic aboneliği - tüm kullanıcılar 'announcements' konusuna abone olsun
    try {
      await FirebaseMessaging.instance.subscribeToTopic('announcements');
      print('✅ "announcements" konusuna abone olundu');
    } catch (e) {
      print('❌ Topic aboneliğinde hata: $e');
    }

    // Emülatörde test bildirim (debug için)
    if (isEmulator) {
      await Future.delayed(Duration(seconds: 5));
      print('⚡ Emülatör test modu: Yerel bildirimler bu sürümde devre dışı.');
    }
  } catch (e) {
    print('❌ Firebase başlatma hatası: $e');
  }

  runApp(const MyApp());
}

// Yerel bildirimleri ayarlama
Future<void> _setupNotifications() async {
  // Android için bildirim kanalı oluştur
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    androidNotificationChannelId, // id
    androidNotificationChannelName, // title
    description: androidNotificationChannelDescription, // description
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(
        'notification'), // Varsayılan ses (opsiyonel)
    enableLights: true,
    enableVibration: true,
  );

  // Android için Flutter yerel bildirim eklentisini hazırla
  final android = AndroidInitializationSettings('@mipmap/ic_launcher');

  // iOS için Flutter yerel bildirim eklentisini hazırla
  final iOS = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );

  // Başlatma ayarlarını birleştir
  final initSettings = InitializationSettings(android: android, iOS: iOS);

  // Flutter yerel bildirim eklentisini başlat
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) {
      print('Bildirime tıklandı: ${notificationResponse.payload}');
      // Bildirime tıklandığında yapılacak işlemleri ekleyin
    },
  );

  // Android için kanalı kaydet
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Android için ön plan bildirim ayarlarını yapılandır
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true, // Bildirimi göster
      badge: true, // Icon badge göster
      sound: true, // Bildirim sesi çal
    );
  }

  // iOS için bildirimleri yapılandır
  if (Platform.isIOS) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true, // Bildirimi göster
      badge: true, // Icon badge göster
      sound: true, // Bildirim sesi çal
    );
  }
}

// Ön planda bildirim gösterme fonksiyonu
Future<void> showLocalNotification(String title, String body,
    {String? payload}) async {
  print('🔔 Yerel bildirim gösteriliyor: $title - $body');

  const androidDetails = AndroidNotificationDetails(
    androidNotificationChannelId,
    androidNotificationChannelName,
    channelDescription: androidNotificationChannelDescription,
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'Yeni Anaokulu',
    color: Colors.blue,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    visibility: NotificationVisibility.public, // Kilit ekranında da göster
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    sound: 'default',
  );

  const generalDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  try {
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond, // benzersiz ID
      title,
      body,
      generalDetails,
      payload: payload,
    );
    print('✅ Yerel bildirim gösterildi');
  } catch (e) {
    print('❌ Yerel bildirim hatası: $e');
  }
}

// Ön planda gelen bildirimleri dinleme
void _setupForegroundNotificationListener() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📬 Ön plan mesajı alındı!');
    print('ℹ️ Ön Plan - Gelen Mesaj ID: ${message.messageId}');
    print('ℹ️ Ön Plan - Bildirim Başlığı: ${message.notification?.title}');
    print('ℹ️ Ön Plan - Bildirim Gövdesi: ${message.notification?.body}');
    print('ℹ️ Ön Plan - Mesaj Verisi (data): ${message.data}');
    print(
        '🔄 Mesaj tipi (data.type): ${message.data['type'] ?? 'belirtilmemiş'}');

    // Kullanıcı öğretmen mi kontrolü yap
    _isUserTeacher().then((isTeacher) {
      print('ℹ️ Ön Plan - Öğretmen mi? : $isTeacher');
      // Öğretmen kullanıcılar bildirim almasın
      if (isTeacher) {
        print(
            '👨‍🏫 Öğretmen kullanıcısı olduğu için ön plan bildirimi işlenmeyecek.');
        return;
      }

      print('ℹ️ Ön Plan - Veli kullanıcısı, mesaj verisi işleniyor...');

      if (message.notification != null) {
        print(
            '📝 Veli için ön plan bildirim içeriği (notification payload): ${message.notification?.title} - ${message.notification?.body}');

        // Yerel bildirim göster
        showLocalNotification(
          message.notification?.title ?? 'Yeni Bildirim',
          message.notification?.body ?? 'Yeni bir bildiriminiz var.',
          payload: message.data.toString(),
        );
      } else if (message.data.isNotEmpty) {
        // Eğer notification boş ama data varsa, data'dan bildirim oluştur
        print(
            'ℹ️ Ön Plan - Notification nesnesi yok, data alanından mesaj işleniyor.');

        // String title = message.data['title'] ?? 'Yeni Bildirim (Data)';
        // String body =
        //     message.data['body'] ?? 'Yeni bir bildiriminiz var (Data)';

        // // Eğer duyuru türü ise ve özel alanlar varsa
        // if (message.data['type'] == 'duyuru') {
        //   print('ℹ️ Ön Plan - "duyuru" tipinde mesaj algılandı.');
        //   if (message.data.containsKey('duyuruBaslik')) {
        //     title = 'Yeni Duyuru: ${message.data['duyuruBaslik']}';
        //     print('ℹ️ Ön Plan - Duyuru Başlığı: $title');
        //   }
        //   if (message.data.containsKey('duyuruIcerik')) {
        //     body = message.data['duyuruIcerik'];
        //     print('ℹ️ Ön Plan - Duyuru İçeriği: $body');
        //   }
        // }

        // showLocalNotification(title, body, payload: message.data.toString());
        print(
            "ℹ️ Ön plan: Yerel bildirimler bu sürümde devre dışı bırakıldı (data payload).");
      } else {
        print(
            '⚠️ Ön Plan - Hem bildirim nesnesi hem de data boş, bildirim işlenemedi!');
      }
    });
  });

  // Mesajın açılması işleyicisi
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🔔 Kullanıcı bildirimi açtı!');
    print('📲 Açılan bildirim verisi: ${message.data}');

    // Burada bildirime tıklandığında yapılacak işlemleri ekleyebilirsiniz
    // Örneğin bildirime tıklandığında belirli bir sayfaya yönlendirme yapabilirsiniz
  });
}

// Kullanıcının öğretmen olup olmadığını kontrol eden yardımcı fonksiyon
Future<bool> _isUserTeacher() async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  try {
    final docSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!docSnap.exists) return false;

    final userData = docSnap.data();
    if (userData == null) return false;

    return userData['isTeacher'] == true;
  } catch (e) {
    print('❌ Öğretmen kontrolü sırasında hata: $e');
    return false;
  }
}

// Bildirim izni fonksiyonu
Future<void> _initializeNotificationPermissions() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Token'ı yenile ve konsola yazdır (sorun giderme için)
  await FirebaseMessaging.instance.deleteToken(); // Mevcut token'ı sil
  String? token = await FirebaseMessaging.instance.getToken(); // Yeni token al
  print('🔄 FCM Token yenilendi: $token');

  if (Platform.isIOS) {
    // iOS için özel izin isteği
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ iOS bildirim izni verildi');
    } else {
      print('❌ iOS bildirim izni durumu: ${settings.authorizationStatus}');
    }
  } else if (Platform.isAndroid) {
    // Android 13+ için bildirim izni isteme
    print('🔔 Android bildirim izni isteniyor...');
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('📱 Android bildirim izni durumu: ${settings.authorizationStatus}');
  }
}

// Cihazın emülatör olup olmadığını kontrol etme
Future<bool> _isRunningOnEmulator() async {
  if (Platform.isAndroid) {
    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.isPhysicalDevice == false ||
          androidInfo.model.toLowerCase().contains('sdk') ||
          androidInfo.model.toLowerCase().contains('emulator') ||
          androidInfo.manufacturer.toLowerCase().contains('genymotion');
    } catch (e) {
      print('Emülatör tespiti sırasında hata: $e');
      // Android'de çoğu emülatörde 'sdk' kelimesi model adında geçer
      return true;
    }
  } else if (Platform.isIOS) {
    try {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      return !iosInfo.isPhysicalDevice;
    } catch (e) {
      print('iOS emülatör tespiti sırasında hata: $e');
      return true;
    }
  }
  return false;
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yeni Anaokulu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3498DB),
          primary: const Color(0xFF3498DB),
          secondary: const Color(0xFF2ECC71),
          tertiary: const Color(0xFFF39C12),
          background: const Color(0xFFF5F7FA),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: const Color(0xFF3498DB),
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFF3498DB), width: 1.5),
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3498DB), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
          hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        dividerTheme: const DividerThemeData(
          space: 20,
          thickness: 1,
          indent: 20,
          endIndent: 20,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey.shade200,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF3498DB),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
        ),
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentTextStyle: GoogleFonts.poppins(
            fontSize: 14,
          ),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'), // Türkçe
        Locale('en',
            ''), // İngilizce (isteğe bağlı, varsayılan olarak eklenebilir)
      ],
      locale:
          const Locale('tr', 'TR'), // Uygulamanın varsayılan dilini Türkçe yap
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  // FCM Token güncelleme fonksiyonu (Artık _updateFcmTokenIfNecessary kullanacak)
  Future<void> _initiateFcmTokenUpdate(User user) async {
    try {
      print('ℹ️ AuthWrapper: FCM token alınıyor ve güncelleniyor...');
      String? token = await FirebaseMessaging.instance.getToken();
      await _updateFcmTokenIfNecessary(token); // Yeni merkezi fonksiyonu çağır
    } catch (e) {
      print('❌ AuthWrapper: FCM token alma/güncelleme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authSnapshot.hasData && authSnapshot.data != null) {
          final user = authSnapshot.data!;
          // Kullanıcı giriş yaptığında token'ı güncelle
          _initiateFcmTokenUpdate(
              user); // Yeniden adlandırılmış fonksiyonu çağır

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (roleSnapshot.hasError || !roleSnapshot.data!.exists) {
                print(
                    'Kullanıcı rolü alınamadı veya belge yok. Oturum kapatılıyor...');
                Future.microtask(() async {
                  await FirebaseAuth.instance.signOut();
                });
                return const Scaffold(
                  body: Center(child: Text('Giriş verisi bulunamadı.')),
                );
              }

              final data = roleSnapshot.data!.data() as Map<String, dynamic>?;
              final bool isTeacher = (data?.containsKey('isTeacher') ?? false)
                  ? data!['isTeacher'] as bool
                  : false;

              return Anasayfa(key: ValueKey(user.uid), isTeacher: isTeacher);
            },
          );
        } else {
          return const GirisEkrani();
        }
      },
    );
  }
}

// FCM ile grup mesajı bildirimi gönderme yardımcı fonksiyonu
Future<void> sendGroupChatNotification({
  required String senderName,
  required String messageText,
  required String senderId,
}) async {
  try {
    // ⚠️ FCM mesajları doğrudan istemciden gönderilemez
    // Bu işlem için bir sunucu (Firebase Cloud Functions) gereklidir
    print('⚠️ Grup mesajı bildirimi için Cloud Functions kurulmalıdır.');
    print('📝 Şu adımları takip edin:');
    print('1. Firebase konsolunda "Functions" bölümünü açın');
    print('2. Yeni bir Cloud Function oluşturun');
    print('3. Aşağıdaki kod örneğini kullanın:');
    print('''
// Cloud Functions örnek kodu:
exports.sendGroupChatNotification = functions.firestore
  .document('class_chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data();
    
    // Mesajı gönderenin adını ve mesaj içeriğini al
    const senderId = messageData.senderId;
    const senderName = messageData.senderDisplayName || 'Bilinmeyen Kullanıcı';
    const messageText = messageData.text || 'Yeni mesaj';
    
    // FCM topic'e bildirim gönder
    const payload = {
      notification: {
        title: `Sınıf Sohbeti: ${senderName}`,
        body: messageText
      },
      data: {
        type: 'group_message',
        chatId: context.params.chatId,
        messageId: context.params.messageId
      }
    };
    
    return admin.messaging().sendToTopic('announcements', payload);
  });
''');

    // Bildirim gönderme işlemini iptal ediyoruz - bildirim gönderen tarafta istenmiyor
    print('ℹ️ Bildirimler: Şu an bildirim gösterilmeyecek.');
    print(
        '⚠️ Diğer kullanıcılara bildirim göndermek için Cloud Functions kurulmalıdır.');
  } catch (e) {
    print('❌ Grup mesajı bildirim hatası: $e');
  }
}

// FCM Token'ı sadece gerekliyse güncelleyen yardımcı fonksiyon
// Bu fonksiyon, onTokenRefresh ve AuthWrapper'dan çağrılabilir.
Future<void> _updateFcmTokenIfNecessary(String? newToken) async {
  final User? user = FirebaseAuth.instance.currentUser;
  if (user == null || newToken == null || newToken.isEmpty) {
    print(
        'ℹ️ Token güncellemesi atlandı: Kullanıcı giriş yapmamış veya token boş.');
    return;
  }

  try {
    print(
        'ℹ️ FCM Token Güncelleme Kontrolü Başladı (Token: $newToken) - Kullanıcı ID: ${user.uid}');
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      print(
          '⚠️ Kullanıcı belgesi bulunamadı (FCM Token Güncelleme Kontrolü): ${user.uid}');
      return;
    }

    final userData = userDoc.data() as Map<String, dynamic>?;
    final String? currentStoredToken = userData?['fcmToken'] as String?;

    if (currentStoredToken != newToken) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': newToken}, SetOptions(merge: true));
      print(
          '📨 Kullanıcı için FCM token kaydedildi/güncellendi (FCM Token Güncelleme Kontrolü): $newToken');
    } else {
      print('ℹ️ Kullanıcının FCM token'
          'ı zaten güncel (FCM Token Güncelleme Kontrolü): $newToken');
    }
  } catch (e) {
    print(
        '❌ FCM token güncelleme kontrolü hatası (FCM Token Güncelleme Kontrolü): $e');
  }
}
