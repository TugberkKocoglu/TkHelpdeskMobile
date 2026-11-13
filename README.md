# TK Helpdesk Mobile

TK Helpdesk'in Flutter ile geliştirdiğim mobil uygulaması. Helpdesk ve Employee kullanıcıları uygulamaya giriş yapabiliyor; talepleri görüntüleyebiliyor, rollerine göre işlem yapabiliyor ve yeni gelişmelerden bildirim alabiliyor.

Mobil tarafta Flutter BLoC, Dio, Socket.IO ve Firebase Messaging kullanıyorum.

Diğer projeler: [API](https://github.com/TugberkKocoglu/TkHelpdeskApi) · [Web](https://github.com/TugberkKocoglu/TkHelpdeskWeb)

## Geliştirme ortamı

Windows 11'de aşağıdaki ortamla çalıştırıp Android emülatöründe giriş ve bildirim testlerini yaptım:

- Flutter **3.41.6** / Dart **3.11.4**
- Android SDK 36
- Android 13 (API 33) emülatörü
- Projedeki Gradle wrapper: **8.14**

**Flutter sürümünü özellikle belirttim:** Windows kurulumunda Flutter 3.50.0'a güncellediğimde projedeki Gradle 8.14 ile uyumsuzluk çıktı. Sürüm doğrulamasını atlamak da işe yaramadı. Flutter 3.41.6'ya döndükten sonra uygulama çalıştı. Bu nedenle ilk denemeyi 3.41.6 ile yapmanızı öneririm.

## Windows kurulumu

Önce Flutter, Android Studio ve Android SDK kurulu olmalı. Android lisansları için:

```powershell
flutter doctor --android-licenses
flutter doctor
```

Flutter eklentileri Windows'ta symlink kullandığı için Geliştirici Modu'nun açık olması gerekiyor. Ayarı açmak için:

```powershell
start ms-settings:developers
```

`flutter doctor` içinde Visual Studio C++ bileşenleriyle ilgili uyarı görünmesi Android emülatöründe çalışmaya engel olmadı; o bölüm Windows masaüstü derlemesi için gerekli.

Projeyi indirin:

```powershell
git clone https://github.com/TugberkKocoglu/TkHelpdeskMobile.git
cd TkHelpdeskMobile
flutter --version
flutter pub get
flutter devices
```

## Android emülatöründe çalıştırma

Önce API'yi ayrı bir terminalde `npm run dev` ile başlatın. Android emülatörü için `localhost` yerine `10.0.2.2` adresi gerekiyor; bu adres emülatörün Windows bilgisayarındaki API'ye ulaşmasını sağlıyor.

```powershell
flutter run -d emulator-5554 --dart-define=API_URL=http://10.0.2.2:5218/api
```

Buradaki `emulator-5554` örnek cihaz kimliği. Farklıysa `flutter devices` çıktısındaki kimliği kullanın.

Fiziksel Android telefonda test edecekseniz Windows'ta `ipconfig` ile bilgisayarın IPv4 adresini öğrenin. Telefonun aynı ağa bağlı olması ve API'ye ağ üzerinden erişebilmesi gerekiyor:

```powershell
flutter run -d CIHAZ_ID --dart-define=API_URL=http://BILGISAYAR_IP:5218/api
```

## Firebase bildirim testi

Android istemcisinin Firebase ayarları `android/app/google-services.json` dosyasında bulunuyor. Bildirim gönderimi ise API tarafında yapılıyor.

Push bildirimlerini açmak için API projesindeki `firebase/service-account.json` dosyasının hazırlanması ve API `.env` dosyasında `FCM_ENABLED=true` olması gerekiyor. Bu dosyanın içeriğini api projesindeki docs altında firebase pdf inde bulabilirsiniz. API yeniden başlatıldıktan sonra mobil uygulamada oturum açın.

Test sırasında:

1. Android'de bildirim iznini verin.
2. Employee hesabıyla giriş yapın. API logunda `POST /api/device-tokens` isteğini görebilirsiniz.
3. Web'den ilgili departmana yeni talep oluşturun veya bildirim üreten bir işlem yapın.
4. Uygulamayı arka plana alıp Android bildiriminin görünüp görünmediğini kontrol edin.

Windows emülatöründe bu akışı test ettim; API'de `[FCM] Başarılı: 1, Başarısız: 0` mesajını gördüm ve Android'e bildirim ulaştı. Emülatörde Google Play hizmetleri bulunması gerekiyor.

## Karşılaştığım sorunlar

| Durum                                            | Nasıl çözdüm / neye bakılabilir?                                                                                                                              |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Building with plugins requires symlink support` | Windows Geliştirici Modu'nu açıp `flutter pub get` komutunu tekrar çalıştırdım.                                                                               |
| Android lisansları eksik                         | `flutter doctor --android-licenses` ile tamamladım.                                                                                                           |
| Flutter 3.50.0, Gradle 9.3.1 istiyor             | Projede kullanılan Gradle 8.14 ile uyumlu test ettiğim Flutter 3.41.6'ya döndüm.                                                                              |
| `ApplicationExtension.getDefaultConfig()`        | Sürüm kontrolünü atlamak bu hatayı çözmedi; Flutter sürümünü eşitleyince derleme çalıştı.                                                                     |
| Android cihaz listede yok                        | Android Studio'dan emülatörü başlatıp `flutter devices` ile kontrol edin. Fiziksel cihaz için USB hata ayıklama açık olmalı.                                  |
| API'ye bağlanmıyor                               | Emülatörde `10.0.2.2`, gerçek telefonda bilgisayarın yerel IP adresi kullanılmalı.                                                                            |
| Bildirim gelmiyor                                | API'nin FCM ayarlarına, cihaz token kaydına, Google Play hizmetlerine ve bildirim iznine bakın.                                                               |
| `/api/auth/refresh` sık tekrarlanıyor            | API yeniden başlatıldıktan sonra bir kez gördüm; istemcileri kapatıp yeniden açınca durdu. Tekrarlanırsa auth interceptor ve refresh yanıtları incelenebilir. |

Flutter 3.41.6'yı [Flutter SDK arşivinden](https://docs.flutter.dev/install/archive) kurabilirsiniz. Daha yeni bir Flutter sürümü denediyseniz `git status --short` ile Android/Gradle dosyalarında otomatik değişiklik oluşup oluşmadığını kontrol etmek faydalı oluyor.

## iOS

iOS uygulamasını çalıştırmak için macOS ve Xcode gerekiyor.
Windows üzerinde iOS derlemesi yapılamıyor.

Mac ve iPhone aynı Wi-Fi ağına bağlı olmalı.
Önce API'yi başlatın ve Mac'in yerel IP adresini öğrenin.

```bash
ipconfig getifaddr en0
flutter devices

flutter run --profile \
  --dart-define=API_URL=http://MAC_IP_ADRESI:5218/api
```

iOS bildirimleri için Firebase yapılandırmasının ve
APNs ayarlarının tamamlanmış olması gerekiyor.

## Ekran Görüntüleri

Uygulamanın Helpdesk ve Employee ekran görüntüleri
[docs/screenshots](docs/screenshots) klasöründe bulunuyor.
