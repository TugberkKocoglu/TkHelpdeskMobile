import 'package:get_it/get_it.dart';

import '../../core/network/auth_token_manager.dart';
import '../../core/network/dio_client.dart';
import '../../core/socket/socket_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/notifications/push_notification_service.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/viewmodel/auth_bloc.dart';

import '../../features/dashboard/data/dashboard_repository.dart';
import '../../features/dashboard/viewmodel/dashboard_bloc.dart';

import '../../features/tickets/data/ticket_repository.dart';
import '../../features/tickets/data/ticket_reference_repository.dart';
import '../../features/tickets/viewmodel/ticket_bloc.dart';
import '../../features/tickets/viewmodel/ticket_detail_bloc.dart';
import '../../features/tickets/viewmodel/ticket_create_bloc.dart';

import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/viewmodel/profile_bloc.dart';

import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/data/device_token_repository.dart';
import '../../features/notifications/viewmodel/notification_bloc.dart';

import '../../core/lifecycle/app_resume_service.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(),
  );

  getIt.registerLazySingleton<AuthTokenManager>(
    () => AuthTokenManager(getIt<SecureStorageService>()),
    dispose: (manager) => manager.dispose(),
  );

  getIt.registerLazySingleton<DioClient>(
    () => DioClient(
      storage: getIt<SecureStorageService>(),
      tokenManager: getIt<AuthTokenManager>(),
    ),
  );

  // Socket.IO
  getIt.registerLazySingleton<SocketService>(
    () => SocketService(
      storage: getIt<SecureStorageService>(),
      tokenManager: getIt<AuthTokenManager>(),
    ),
    dispose: (service) => service.dispose(),
  );

  // Firebase cihaz token API
  getIt.registerLazySingleton<DeviceTokenRepository>(
    () => DeviceTokenRepository(dioClient: getIt<DioClient>()),
  );

  // Firebase push bildirim servisi
  getIt.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(getIt<DeviceTokenRepository>()),
    dispose: (service) => service.dispose(),
  );

  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(
      dioClient: getIt<DioClient>(),
      storage: getIt<SecureStorageService>(),
      tokenManager: getIt<AuthTokenManager>(),
    ),
  );

  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      getIt<AuthRepository>(),
      getIt<AuthTokenManager>(),
      getIt<SocketService>(),
      getIt<PushNotificationService>(),
    ),
  );

  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepository(dioClient: getIt<DioClient>()),
  );

  getIt.registerFactory<DashboardBloc>(
    () => DashboardBloc(getIt<DashboardRepository>()),
  );

  getIt.registerLazySingleton<TicketRepository>(
    () => TicketRepository(dioClient: getIt<DioClient>()),
  );

  getIt.registerFactory<TicketBloc>(
    () => TicketBloc(getIt<TicketRepository>()),
  );

  getIt.registerFactory<TicketDetailBloc>(
    () => TicketDetailBloc(getIt<TicketRepository>()),
  );

  getIt.registerLazySingleton<TicketReferenceRepository>(
    () => TicketReferenceRepository(dioClient: getIt<DioClient>()),
  );

  getIt.registerFactory<TicketCreateBloc>(
    () => TicketCreateBloc(
      ticketRepository: getIt<TicketRepository>(),
      referenceRepository: getIt<TicketReferenceRepository>(),
    ),
  );

  getIt.registerLazySingleton<ProfileRepository>(
    () => ProfileRepository(
      dioClient: getIt<DioClient>(),
      referenceRepository: getIt<TicketReferenceRepository>(),
    ),
  );

  getIt.registerFactory<ProfileBloc>(
    () => ProfileBloc(getIt<ProfileRepository>()),
  );

  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepository(dioClient: getIt<DioClient>()),
  );

  getIt.registerFactory<NotificationBloc>(
    () => NotificationBloc(getIt<NotificationRepository>()),
  );

  getIt.registerLazySingleton<AppResumeService>(
    () => AppResumeService(),
    dispose: (service) => service.dispose(),
  );
}
