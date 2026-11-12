import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../network/api_config.dart';
import '../network/auth_token_manager.dart';
import '../storage/secure_storage_service.dart';

class SocketService {
  SocketService({
    required SecureStorageService storage,
    required AuthTokenManager tokenManager,
  }) : _storage = storage,
       _tokenManager = tokenManager;

  final SecureStorageService _storage;
  final AuthTokenManager _tokenManager;

  io.Socket? _socket;
  Timer? _reconnectTimer;

  final _ticketChangedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final _notificationRefreshController = StreamController<void>.broadcast();

  final _connectionController = StreamController<bool>.broadcast();

  bool _enabled = false;
  bool _connecting = false;
  bool _disposed = false;
  bool _forceRefresh = false;

  int _generation = 0;

  static const _retryDelay = Duration(seconds: 5);

  Stream<Map<String, dynamic>> get ticketChanged =>
      _ticketChangedController.stream;

  Stream<void> get notificationRefresh => _notificationRefreshController.stream;

  Stream<bool> get connectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  String get _serverUrl {
    final uri = Uri.parse(ApiConfig.baseUrl);

    final path = uri.path.endsWith('/api')
        ? uri.path.substring(0, uri.path.length - 4)
        : uri.path;

    return uri.replace(path: path).toString().replaceFirst(RegExp(r'/$'), '');
  }

  bool _tokenIsExpired(String token) {
    try {
      final parts = token.split('.');

      if (parts.length != 3) return true;

      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;

      final exp = payload['exp'];

      if (exp is! num) return true;

      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);

      // Süresi dolmak üzere olan token'ı da yenile.
      return DateTime.now().add(const Duration(seconds: 30)).isAfter(expiresAt);
    } catch (_) {
      return true;
    }
  }

  Future<String> _getValidToken() async {
    final token = await _storage.getAccessToken();

    if (!_forceRefresh &&
        token != null &&
        token.isNotEmpty &&
        !_tokenIsExpired(token)) {
      return token;
    }

    final refreshed = await _tokenManager.refreshTokens();
    _forceRefresh = false;

    return refreshed.accessToken;
  }

  Future<void> connect() async {
    if (_disposed || _connecting || isConnected) return;

    _enabled = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _connecting = true;
    final generation = ++_generation;

    try {
      final token = await _getValidToken();

      if (!_enabled || _disposed || generation != _generation) {
        return;
      }

      _socket?.dispose();
      _socket = null;

      final socket = io.io(
        _serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .disableReconnection()
            .setAuth({'token': token})
            .build(),
      );

      _socket = socket;

      socket.onConnect((_) {
        if (generation != _generation || !_enabled) return;

        _connecting = false;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;

        _connectionController.add(true);
      });

      socket.onDisconnect((_) {
        if (generation != _generation || !_enabled) return;

        _connecting = false;
        _connectionController.add(false);

        _scheduleReconnect();
      });

      socket.onConnectError((error) {
        if (generation != _generation || !_enabled) return;

        _connecting = false;
        _connectionController.add(false);

        final message = error.toString().toLowerCase();

        if (message.contains('token') ||
            message.contains('yetkisiz') ||
            message.contains('unauthorized')) {
          _forceRefresh = true;
        }

        _scheduleReconnect();
      });

      socket.on('ticket:changed', (data) {
        if (generation != _generation || !_enabled) return;

        if (data is Map) {
          _ticketChangedController.add(Map<String, dynamic>.from(data));
        }
      });

      socket.on('notification:refresh', (_) {
        if (generation != _generation || !_enabled) return;

        _notificationRefreshController.add(null);
      });

      _connecting = false;
      socket.connect();
    } catch (_) {
      if (generation == _generation && _enabled) {
        _connectionController.add(false);
        _scheduleReconnect();
      }
    } finally {
      if (generation == _generation) {
        _connecting = false;
      }
    }
  }

  void _scheduleReconnect() {
    if (!_enabled || _disposed) return;

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(_retryDelay, () {
      if (_enabled && !_disposed) {
        unawaited(connect());
      }
    });
  }

  void disconnect() {
    _enabled = false;
    _forceRefresh = false;
    _connecting = false;
    _generation++;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _socket?.dispose();
    _socket = null;

    if (!_disposed) {
      _connectionController.add(false);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;

    disconnect();
    _disposed = true;

    await _ticketChangedController.close();
    await _notificationRefreshController.close();
    await _connectionController.close();
  }
}
