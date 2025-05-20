/* eslint-disable max-len */
// V2 imports
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";

// Admin SDK import
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// YENİ ADI VE TETİKLEYİCİSİYLE ANA DUYURU FONKSİYONUMUZ
export const notifyParentsOnNewAnnouncement = onDocumentCreated(
  "notifications/{docId}",
  async (event) => {
    logger.info(
      "Yeni duyuru (notifications) oluşturuldu, bildirim gönderimi başlıyor..."
    );
    logger.info(`Duyuru ID: ${event.params.docId}`);

    const snap = event.data;
    if (!snap) {
      logger.error("Olayla ilişkili veri yok (event.data boş)");
      return;
    }
    const duyuruData = snap.data();

    if (!duyuruData) {
      logger.error("Duyuru verisi (snap.data()) alınamadı.");
      return;
    }

    const baslik = duyuruData.baslik || "Yeni Duyuru";
    const icerik = duyuruData.icerik || "Yeni bir bildiriminiz var.";

    logger.info(`Alınan Başlık: "${baslik}", Alınan İçerik: "${icerik}"`);

    try {
      const parentsSnapshot = await db
        .collection("users")
        .where("isTeacher", "==", false)
        .get();

      if (parentsSnapshot.empty) {
        logger.warn(
          "Bildirim gönderilecek veli bulunamadı (isTeacher == false)."
        );
        return;
      }

      logger.info(
        `Toplam ${parentsSnapshot.size} veli kullanıcısı bulundu.`
      );

      const tokens: string[] = [];
      parentsSnapshot.forEach((parentDoc) => {
        const parentData = parentDoc.data();
        if (
          parentData &&
          parentData.fcmToken &&
          typeof parentData.fcmToken === "string"
        ) {
          tokens.push(parentData.fcmToken);
        } else {
          logger.warn(
            `Kullanıcı ${parentDoc.id} için geçerli fcmToken bulunamadı.`
          );
        }
      });

      if (tokens.length === 0) {
        logger.warn("Bildirim gönderilecek geçerli FCM token bulunamadı.");
        return;
      }

      logger.info(`${tokens.length} cihaza bildirim gönderiliyor...`);

      const notificationBody =
        icerik.length > 100 ? `${icerik.substring(0, 97)}...` : icerik;

      const message: admin.messaging.MulticastMessage = {
        notification: {
          title: `Yeni Duyuru: ${baslik}`,
          body: notificationBody,
        },
        data: {
          type: "duyuru",
          duyuruId: event.params.docId,
        },
        tokens: tokens,
      };

      const response = await messaging.sendEachForMulticast(message);
      logger.info(
        `Bildirim sonucu: ${response.successCount} başarılı, ` +
        `${response.failureCount} başarısız.`
      );

      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            logger.error(
              `Token ${tokens[idx]} için bildirim hatası: ` +
              `${resp.error.code} - ${resp.error.message}`
            );
          }
        });
      }
    } catch (error) {
      logger.error("Bildirim gönderme sürecinde genel hata:", error);
    }
  }
); // Fonksiyon tanımının sonu
// eol-last için kısa yorum.
// <- BU YORUMDAN SONRA BOŞ BİR SATIR OLMALI (ENTER'A BASILMIŞ)

// YENİ ÖZEL MESAJ BİLDİRİM FONKSİYONU
export const sendChatMessageNotification = onDocumentCreated(
  {
    document: "private_chats/{chatId}/messages/{messageId}",
    region: "europe-west1", // veya kullandığınız bölge
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.error(
        "[ChatNotify] Yeni mesaj olayıyla ilişkili veri yok (event.data boş)"
      );
      return;
    }
    const messageData = snap.data();

    if (!messageData) {
      logger.error("[ChatNotify] Yeni mesaj belgesinde veri bulunamadı.");
      return;
    }

    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    logger.info(
      "[ChatNotify] Yeni mesaj " + messageId +
      " (chat: " + chatId + ") için bildirim işleniyor."
    );

    const senderId = messageData.senderId;
    const recipientId = messageData.recipientId;
    const senderName = messageData.senderDisplayName || "Bir kullanıcı";
    let messageText = messageData.text || "size bir mesaj gönderdi.";

    if (!recipientId) {
      logger.warn(
        "[ChatNotify] Alıcı ID (recipientId) mesajda bulunamadı " +
        "(chat: " + chatId + ", msg: " + messageId + ") " +
        "Bildirim gönderilmeyecek."
      );
      return;
    }

    if (senderId === recipientId) {
      logger.info(
        "[ChatNotify] Gönderen (" + senderId + ") " +
        "aynı zamanda alıcı (" + recipientId + "). " +
        "Bildirim gönderilmeyecek."
      );
      return;
    }

    // Mesaj metni çok uzunsa kısalt (bildirim için)
    if (messageText.length > 100) {
      messageText = messageText.substring(0, 97) + "...";
    }

    let recipientDoc;
    try {
      recipientDoc = await db
        .collection("users")
        .doc(recipientId)
        .get();
    } catch (error) {
      logger.error(
        "[ChatNotify] Alıcı (" + recipientId + ") kullanıcı " +
        "belgesi okunurken hata:",
        error
      );
      return;
    }

    if (!recipientDoc.exists) {
      logger.warn(
        "[ChatNotify] Alıcı kullanıcı belgesi bulunamadı " +
        "(UID: " + recipientId + "). Bildirim gönderilmeyecek."
      );
      return;
    }

    const recipientData = recipientDoc.data();
    if (!recipientData || !recipientData.fcmToken) {
      logger.warn(
        "[ChatNotify] Alıcının FCM token'ı bulunamadı " +
        "(UID: " + recipientId + "). Bildirim gönderilmeyecek."
      );
      return;
    }

    const fcmToken = recipientData.fcmToken;

    const payload: admin.messaging.Message = {
      notification: {
        title: `Yeni Mesaj: ${senderName}`,
        body: messageText,
      },
      data: {
        type: "private_chat",
        chatId: chatId,
        senderId: senderId,
        recipientId: recipientId,
        senderName: senderName,
      },
      android: {
        notification: {
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
      token: fcmToken,
    };
    // Trailing space kaldırıldı.
    try {
      logger.info(
        "[ChatNotify] Bildirim \"" +
        (recipientData.displayName || recipientId) +
        "\" (" + recipientId + ") kullanıcısına token " +
        "(" + fcmToken.substring(0, 10) + "...) " +
        "ile gönderiliyor."
      );

      const response = await messaging.send(payload);

      logger.info(
        "[ChatNotify] Bildirim başarıyla gönderildi " +
        "(Message ID: " + response + ")."
      );
    } catch (error: unknown) { // any yerine unknown kullanıldı
      const fcmTokenSubstring = fcmToken.substring(0, 20);
      logger.error(
        "[ChatNotify] Bildirim gönderme hatası " +
        "(token: " + fcmTokenSubstring + "...):",
        error
      );
      // FirebaseError tip kontrolü
      if (
        error instanceof Error && // Temel Error kontrolü
        "code" in error // FirebaseError'lar genelde 'code' özelliğine sahiptir
      ) {
        const firebaseError = error as {code: string; message: string};
        if (
          firebaseError.code === "messaging/invalid-registration-token" ||
          firebaseError.code === "messaging/registration-token-not-registered"
        ) {
          logger.warn(
            "[ChatNotify] Geçersiz token (" + fcmTokenSubstring + "...) " +
            recipientId + " " +
            "için. Firestore'dan silinmesi düşünülebilir."
          );
          // await db.collection("users").doc(recipientId)
          //   .update({ fcmToken: admin.firestore.FieldValue.delete() });
        }
      }
    }
  }
); // Fonksiyon tanımının sonu
// eol-last için kısa yorum.
// <- BU YORUMDAN SONRA BOŞ BİR SATIR OLMALI (ENTER'A BASILMIŞ)
// Trailing space kaldırıldı.

// GRUP SOHBET BİLDİRİM FONKSİYONU
export const sendGroupChatNotification = onDocumentCreated(
  {
    document: "class_chats/{chatId}/messages/{messageId}",
    region: "europe-west1", // veya kullandığınız bölge
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      logger.error(
        "[GroupChatNotify] Yeni grup mesajı olayıyla ilişkili veri yok"
      );
      return;
    }
    const messageData = snap.data();

    if (!messageData) {
      logger.error(
        "[GroupChatNotify] Yeni grup mesaj belgesinde veri bulunamadı."
      );
      return;
    }

    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    logger.info(
      `[GroupChatNotify] Yeni grup mesajı ${messageId} ` +
      `(chat: ${chatId}) için bildirim işleniyor.`
    );

    const senderId = messageData.senderId;
    const senderName = messageData.senderDisplayName || "Bir kullanıcı";
    let messageText =
      messageData.text || "sınıf sohbetinde bir mesaj paylaştı.";

    // Mesaj metni çok uzunsa kısalt (bildirim için)
    if (messageText.length > 100) {
      messageText = messageText.substring(0, 97) + "...";
    }

    try {
      // Tüm velilerin FCM token'larını al
      const parentsSnapshot = await db
        .collection("users")
        .where("isTeacher", "==", false)
        .where("userRole", "==", "veli") // Sadece velilere gönder
        .get();

      if (parentsSnapshot.empty) {
        logger.warn(
          "[GroupChatNotify] Bildirim gönderilecek veli bulunamadı."
        );
        return;
      }

      logger.info(
        `[GroupChatNotify] Toplam ${parentsSnapshot.size} veli kullanıcısı` +
        " bulundu."
      );

      const tokens: string[] = [];
      parentsSnapshot.forEach((parentDoc) => {
        // Gönderici kendine bildirim almasın
        if (parentDoc.id === senderId) {
          logger.info(
            `[GroupChatNotify] Gönderici (${senderId}) kendi mesajı için` +
            " bildirim almayacak."
          );
          return; // Bu kullanıcıyı atla
        }

        const parentData = parentDoc.data();
        if (
          parentData &&
          parentData.fcmToken &&
          typeof parentData.fcmToken === "string"
        ) {
          tokens.push(parentData.fcmToken);
        } else {
          logger.warn(
            `[GroupChatNotify] Kullanıcı ${parentDoc.id} için geçerli ` +
            "fcmToken bulunamadı."
          );
        }
      });

      if (tokens.length === 0) {
        logger.warn(
          "[GroupChatNotify] Bildirim gönderilecek geçerli FCM token" +
          " bulunamadı."
        );
        return;
      }

      logger.info(
        `[GroupChatNotify] ${tokens.length} cihaza grup bildirim` +
        " gönderiliyor..."
      );

      const message: admin.messaging.MulticastMessage = {
        notification: {
          title: `Sınıf Sohbeti: ${senderName}`,
          body: messageText,
        },
        data: {
          type: "group_message",
          chatId: chatId,
          messageId: messageId,
          senderId: senderId,
        },
        android: {
          notification: {
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        tokens: tokens,
      };

      const response = await messaging.sendEachForMulticast(message);
      logger.info(
        `[GroupChatNotify] Bildirim sonucu: ${response.successCount} başarılı, ` +
        `${response.failureCount} başarısız.`
      );

      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            logger.error(
              `[GroupChatNotify] Token ${tokens[idx].substring(0, 10)}...:`
            );
            logger.error(
              `${resp.error.code} - ${resp.error.message}`
            );
          }
        });
      }
    } catch (error) {
      logger.error(
        "[GroupChatNotify] Bildirim gönderme sürecinde genel hata:",
        error
      );
    }
  }
);
