import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key, this.repository});

  final ProfileRepository? repository;

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  late final ProfileRepository _repository =
      widget.repository ?? ProfileRepository();
  List<Map<String, dynamic>> _notifications = const [];
  bool _loading = true;
  bool _markingRead = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await _repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    if (_markingRead || !_notifications.any((item) => item['read'] != true)) {
      return;
    }
    setState(() => _markingRead = true);
    try {
      await _repository.readAllNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((item) => {...item, 'read': true})
            .toList(growable: false);
        _markingRead = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _markingRead = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notifications: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.any((item) => item['read'] != true);
    return Scaffold(
      backgroundColor: const Color(0xFF080B0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080B0A),
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: unread && !_markingRead ? _markAllRead : null,
            icon: _markingRead
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _InboxError(message: _error!, onRetry: _load)
          : _notifications.isEmpty
          ? const _EmptyInbox()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  final read = item['read'] == true;
                  final title = item['title'] is String
                      ? item['title'] as String
                      : 'RIVALON update';
                  final body = item['body'] is String
                      ? item['body'] as String
                      : '';
                  final date = item['date'] is String
                      ? item['date'] as String
                      : '';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111614),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: read
                            ? const Color(0xFF28312D)
                            : const Color(0xFF55D6A0),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Icon(
                            read
                                ? Icons.notifications_none
                                : Icons.notifications_active_outlined,
                            color: read
                                ? const Color(0xFF7E8A84)
                                : const Color(0xFF55D6A0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (!read)
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF55D6A0),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                body,
                                style: const TextStyle(
                                  color: Color(0xFFC1CAC5),
                                  height: 1.4,
                                ),
                              ),
                              if (date.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  date,
                                  style: const TextStyle(
                                    color: Color(0xFF7E8A84),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none,
            size: 44,
            color: Color(0xFF7E8A84),
          ),
          const SizedBox(height: 12),
          Text(
            'You are all caught up',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            'New account, wallet and tournament updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9AA59F)),
          ),
        ],
      ),
    ),
  );
}

class _InboxError extends StatelessWidget {
  const _InboxError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, color: Color(0xFFFF8B80), size: 36),
          const SizedBox(height: 12),
          const Text('Could not load notifications'),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF9AA59F)),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
