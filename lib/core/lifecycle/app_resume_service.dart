import 'dart:async';

class AppResumeService {
  AppResumeService();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get onResume => _controller.stream;

  void notifyResumed() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
