import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/notifications/data/device_token_repository.dart';

class PushNotificationService {
  PushNotificationService(this._repository);

  final DeviceTokenRepository _repository;

  StreamSubscription<String>? _tokenSubscription;

  Future<void> _pendingRegistration = Future.value();

  bool _active = false;
  int _generation = 0;
  String? _registeredToken;

  bool get _supportedPlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  void start() {
    if (_active) return;
    if (!_supportedPlatform || Firebase.apps.isEmpty) return;

    _active = true;
    final generation = ++_generation;

    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) {
        _queueRegistration(token, generation);
      },
      onError: (Object error) {
        debugPrint('[FCM] Token yenileme hatası: $error');
      },
    );

    unawaited(_initialize(generation));
  }

  Future<void> _initialize(int generation) async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (!_isCurrent(generation)) return;

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Bildirim izni reddedildi.');
        return;
      }

      if (Platform.isIOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

        // iOS cihazın APNs kaydını tamamlamasını bekle.
        String? apnsToken;

        for (var attempt = 0; attempt < 20; attempt++) {
          if (!_isCurrent(generation)) return;

          apnsToken = await messaging.getAPNSToken();

          if (apnsToken != null && apnsToken.isNotEmpty) {
            break;
          }

          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        if (apnsToken == null || apnsToken.isEmpty) {
          debugPrint('[FCM] APNs token henüz alınamadı.');
          return;
        }
      }

      if (!_isCurrent(generation)) return;

      final token = await messaging.getToken();

      if (token == null || token.isEmpty) {
        debugPrint('[FCM] FCM token alınamadı.');
        return;
      }

      _queueRegistration(token, generation);
    } catch (error) {
      debugPrint('[FCM] Başlatma hatası: $error');
    }
  }

  bool _isCurrent(int generation) => _active && generation == _generation;

  void _queueRegistration(String token, int generation) {
    _pendingRegistration = _pendingRegistration.catchError((Object _) {}).then((
      _,
    ) async {
      if (!_isCurrent(generation)) return;

      if (_registeredToken == token) return;

      try {
        await _repository.register(token: token, platform: _platform);

        _registeredToken = token;

        debugPrint('[FCM] Cihaz token kaydedildi.');
      } catch (error) {
        debugPrint('[FCM] Token kayıt hatası: $error');
      }
    });
  }

  Future<void> stop({bool deactivate = true}) async {
    if (!_active && _registeredToken == null) return;

    _active = false;
    ++_generation;

    await _tokenSubscription?.cancel();
    _tokenSubscription = null;

    // Önceden başlatılan kayıt isteği tamamlanmadan
    // DELETE isteği gönderilmesin.
    try {
      await _pendingRegistration;
    } catch (_) {}

    final token = _registeredToken;
    _registeredToken = null;

    if (deactivate && token != null) {
      try {
        await _repository.deactivate(token);
        debugPrint('[FCM] Cihaz token pasifleştirildi.');
      } catch (error) {
        debugPrint('[FCM] Token pasifleştirme hatası: $error');
      }
    }
  }

  Future<void> dispose() async {
    await stop(deactivate: false);
  }
}
