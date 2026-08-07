import 'dart:async';

class SubscriptionEvents {
  SubscriptionEvents._();
  static final SubscriptionEvents instance = SubscriptionEvents._();

  final _controller = StreamController<void>.broadcast();

  Stream<void> get onActivated => _controller.stream;

  void notifyActivated() {
    _controller.add(null);
  }
}