import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/utils.dart';
import '../../data/models/notification_models.dart';

/// Notification Repository
class NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepository(this._apiClient);

  /// Get notifications
  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/notifications',
        queryParameters: {
          'page': page,
          'limit': pageSize,
        },
      );

      final data = response as Map<String, dynamic>;
      final notifications = (data['data'] as List? ?? [])
          .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList();

      return notifications;
    } catch (e) {
      logger.e('Get notifications error: $e');
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiClient.patch(
        '/notifications/$notificationId/read',
      );
    } catch (e) {
      logger.e('Mark notification as read error: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _apiClient.delete('/notifications/$notificationId');
    } catch (e) {
      logger.e('Delete notification error: $e');
    }
  }
}

/// Notification State
enum NotificationStatus {
  initial,
  loading,
  loaded,
  error,
}

class NotificationsState {
  final NotificationStatus status;
  final List<AppNotification> notifications;
  final String? error;
  final int unreadCount;

  const NotificationsState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.error,
    this.unreadCount = 0,
  });

  bool get isLoading => status == NotificationStatus.loading;
  bool get isLoaded => status == NotificationStatus.loaded;

  NotificationsState copyWith({
    NotificationStatus? status,
    List<AppNotification>? notifications,
    String? error,
    int? unreadCount,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Notification Notifier
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationRepository _repository;

  NotificationsNotifier(this._repository) : super(const NotificationsState());

  /// Load notifications
  Future<void> loadNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    state = state.copyWith(status: NotificationStatus.loading);
    try {
      final notifications = await _repository.getNotifications(
        page: page,
        pageSize: pageSize,
      );

      final unreadCount = notifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        status: NotificationStatus.loaded,
        notifications: notifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      logger.e('Load notifications error: $e');
      state = state.copyWith(
        status: NotificationStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      logger.e('Mark as read error: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);

      // Update local state
      final updatedNotifications = state.notifications
          .where((n) => n.id != notificationId)
          .toList();

      final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: unreadCount,
      );
    } catch (e) {
      logger.e('Delete notification error: $e');
    }
  }

  /// Add new notification (for real-time updates)
  void addNotification(AppNotification notification) {
    final updatedNotifications = [notification, ...state.notifications];
    final unreadCount = updatedNotifications.where((n) => !n.isRead).length;

    state = state.copyWith(
      notifications: updatedNotifications,
      unreadCount: unreadCount,
    );
  }
}

/// Notification Repository Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return NotificationRepository(apiClient);
});

/// Notifications Provider
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  return NotificationsNotifier(repository);
});

/// Unread notifications count provider
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationsProvider);
  return state.unreadCount;
});
