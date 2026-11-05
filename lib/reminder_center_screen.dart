import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'main.dart';

class ReminderCenterScreen extends StatefulWidget {
  final List<Book> books;
  const ReminderCenterScreen({super.key, required this.books});
  @override
  State<ReminderCenterScreen> createState() => _ReminderCenterScreenState();
}

class _ReminderCenterScreenState extends State<ReminderCenterScreen> {
  final plugin = FlutterLocalNotificationsPlugin();
  bool daily = false, draft = false, ready = false, saving = false;
  TimeOfDay dailyTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay draftTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _init() async {
    if (ready) return;
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));
    await plugin.initialize(settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ));
    ready = true;
  }

  Future<void> _load() async {
    try {
      await _init();
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        daily = p.getBool('haven_daily_reminder') ?? false;
        draft = p.getBool('haven_draft_reminder') ?? false;
        dailyTime = TimeOfDay(hour: p.getInt('haven_daily_hour') ?? 19, minute: p.getInt('haven_daily_minute') ?? 0);
        draftTime = TimeOfDay(hour: p.getInt('haven_draft_hour') ?? 18, minute: p.getInt('haven_draft_minute') ?? 0);
      });
    } catch (e) { debugPrint('Reminder initialisation failed: $e'); }
  }

  tz.TZDateTime _next(TimeOfDay t, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(tz.local, now.year, now.month, now.day, t.hour, t.minute);
    if (weekday == null) {
      if (!date.isAfter(now)) date = date.add(const Duration(days: 1));
    } else {
      final days = (weekday - now.weekday) % 7;
      date = date.add(Duration(days: days));
      if (!date.isAfter(now)) date = date.add(const Duration(days: 7));
    }
    return date;
  }

  Future<void> _pick(bool isDraft) async {
    final result = await showTimePicker(context: context, initialTime: isDraft ? draftTime : dailyTime);
    if (result != null) setState(() { if (isDraft) { draftTime = result; } else { dailyTime = result; } });
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await _init();
      if (daily || (draft && widget.books.isNotEmpty)) {
        final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final allowed = await android?.requestNotificationsPermission() ?? true;
        if (!allowed) throw Exception('Notification permission was not granted');
      }
      await plugin.cancel(id: 7101);
      await plugin.cancel(id: 7102);
      const dailyDetails = NotificationDetails(android: AndroidNotificationDetails(
        'haven_daily_writing', 'Daily writing',
        channelDescription: 'A daily reminder to write',
        importance: Importance.defaultImportance, priority: Priority.defaultPriority,
      ));
      const draftDetails = NotificationDetails(android: AndroidNotificationDetails(
        'haven_draft_checkin', 'Draft check-ins',
        channelDescription: 'A weekly reminder to revisit unfinished drafts',
        importance: Importance.defaultImportance, priority: Priority.defaultPriority,
      ));
      if (daily) {
        await plugin.zonedSchedule(
          id: 7101, title: 'A little time for your story',
          body: 'Open Writer’s Haven and add a few words today.',
          scheduledDate: _next(dailyTime), notificationDetails: dailyDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      if (draft && widget.books.isNotEmpty) {
        await plugin.zonedSchedule(
          id: 7102, title: 'Your drafts are waiting',
          body: 'Take a moment to revisit one of your books in progress.',
          scheduledDate: _next(draftTime, weekday: DateTime.monday),
          notificationDetails: draftDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
      final p = await SharedPreferences.getInstance();
      await p.setBool('haven_daily_reminder', daily);
      await p.setBool('haven_draft_reminder', draft);
      await p.setInt('haven_daily_hour', dailyTime.hour);
      await p.setInt('haven_daily_minute', dailyTime.minute);
      await p.setInt('haven_draft_hour', draftTime.hour);
      await p.setInt('haven_draft_minute', draftTime.minute);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder settings saved on this device.')));
    } catch (e) {
      debugPrint('Reminder scheduling failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save reminders. Check notification permission and try again.')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  String _time(TimeOfDay t) => t.format(context);

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Writing reminders')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(24)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.notifications_active_outlined, color: Colors.white, size: 30),
            SizedBox(height: 12),
            Text('Make space for your stories', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('Gentle reminders help you return to the page.', style: TextStyle(color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 18),
        Card(child: Column(children: [
          SwitchListTile(
            value: daily, onChanged: (v) => setState(() => daily = v),
            secondary: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Daily writing reminder', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Get a nudge every day at your chosen time.'),
          ),
          if (daily) ListTile(title: const Text('Reminder time'), trailing: TextButton(onPressed: () => _pick(false), child: Text(_time(dailyTime)))),
        ])),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          SwitchListTile(
            value: draft, onChanged: (v) => setState(() => draft = v),
            secondary: const Icon(Icons.menu_book_outlined),
            title: const Text('Unfinished draft check-in', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('A weekly Monday reminder to revisit your books.'),
          ),
          if (draft) ListTile(title: const Text('Check-in time'), trailing: TextButton(onPressed: () => _pick(true), child: Text(_time(draftTime)))),
          if (draft && widget.books.isEmpty)
            const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 12), child: Text('Create a book first; the weekly reminder will start once you have one.', style: TextStyle(fontSize: 12))),
        ])),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: saving ? null : _save,
          icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
          label: Text(saving ? 'Saving…' : 'Save reminders'),
        ),
        const SizedBox(height: 12),
        const Text('Reminders run on this device using its local time. Android may deliver inexact reminders a little later. You can change or turn them off here.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }
}
