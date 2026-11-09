import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class CalendarScreen extends StatefulWidget {
  final String userId;

  const CalendarScreen({super.key, required this.userId});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static final _notifications = FlutterLocalNotificationsPlugin();
  late final String _storageKey;
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  List<_WritingTask> _tasks = [];
  int _dailyGoal = 500;
  int _weeklyGoal = 3000;
  int _monthlyGoal = 12000;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _storageKey = 'writers_haven_calendar_${widget.userId}';
    _initializeNotifications();
    _loadData();
  }

  Future<void> _initializeNotifications() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Lagos'));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _notifications.initialize(settings);
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (error) {
      debugPrint('Notification setup unavailable: $error');
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _tasks = (data['tasks'] as List<dynamic>? ?? [])
            .map((item) => _WritingTask.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        _dailyGoal = (data['dailyGoal'] as num?)?.toInt() ?? 500;
        _weeklyGoal = (data['weeklyGoal'] as num?)?.toInt() ?? 3000;
        _monthlyGoal = (data['monthlyGoal'] as num?)?.toInt() ?? 12000;
      } catch (error) {
        debugPrint('Could not load writing calendar: $error');
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode({
      'tasks': _tasks.map((task) => task.toJson()).toList(),
      'dailyGoal': _dailyGoal,
      'weeklyGoal': _weeklyGoal,
      'monthlyGoal': _monthlyGoal,
    }));
  }

  List<_WritingTask> get _selectedTasks => _tasks
      .where((task) => DateUtils.isSameDay(task.dueDate, _selectedDate))
      .toList()
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  int get _completedToday => _selectedTasks.where((task) => task.completed).length;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Choose a writing day',
    );
    if (picked != null) setState(() => _selectedDate = DateUtils.dateOnly(picked));
  }

  Future<void> _showTaskDialog({_WritingTask? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final noteController = TextEditingController(text: existing?.notes ?? '');
    DateTime dueDate = existing?.dueDate ?? _selectedDate;
    TimeOfDay? reminderTime = existing?.reminderTime;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_TaskDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: Text(existing == null ? 'Plan a writing task' : 'Edit task'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Task title',
                      hintText: 'e.g. Finish chapter two',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Add a task title'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Due date'),
                    subtitle: Text(_dateLabel(dueDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        refreshDialog(() => dueDate = DateUtils.dateOnly(picked));
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_active_outlined),
                    title: const Text('Reminder'),
                    subtitle: Text(reminderTime == null
                        ? 'No reminder'
                        : 'At ${reminderTime!.format(context)}'),
                    trailing: reminderTime == null
                        ? const Icon(Icons.add_alarm)
                        : IconButton(
                            tooltip: 'Remove reminder',
                            onPressed: () => refreshDialog(() => reminderTime = null),
                            icon: const Icon(Icons.close),
                          ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: reminderTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        refreshDialog(() => reminderTime = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  dialogContext,
                  _TaskDraft(
                    title: titleController.text.trim(),
                    notes: noteController.text.trim(),
                    dueDate: dueDate,
                    reminderTime: reminderTime,
                  ),
                );
              },
              child: const Text('Save task'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    noteController.dispose();
    if (result == null || !mounted) return;

    final task = existing ??
        _WritingTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: result.title,
          notes: result.notes,
          dueDate: result.dueDate,
        );
    task
      ..title = result.title
      ..notes = result.notes
      ..dueDate = result.dueDate
      ..reminderTime = result.reminderTime;

    setState(() {
      if (existing == null) {
        _tasks.add(task);
      }
      _selectedDate = result.dueDate;
    });
    await _scheduleReminder(task);
    await _saveData();
  }

  Future<void> _scheduleReminder(_WritingTask task) async {
    final notificationId = task.id.hashCode & 0x7fffffff;
    await _notifications.cancel(notificationId);
    final time = task.reminderTime;
    if (time == null || task.completed) return;

    final scheduled = tz.TZDateTime(
      tz.local,
      task.dueDate.year,
      task.dueDate.month,
      task.dueDate.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a reminder time in the future.')),
        );
      }
      task.reminderTime = null;
      return;
    }

    await _notifications.zonedSchedule(
      notificationId,
      'Time to write',
      task.title,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'writers_haven_reminders',
          'Writing reminders',
          channelDescription: 'Reminders for your writing plans',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> _toggleTask(_WritingTask task, bool completed) async {
    setState(() => task.completed = completed);
    if (completed) {
      await _notifications.cancel(task.id.hashCode & 0x7fffffff);
    } else {
      await _scheduleReminder(task);
    }
    await _saveData();
  }

  Future<void> _deleteTask(_WritingTask task) async {
    await _notifications.cancel(task.id.hashCode & 0x7fffffff);
    setState(() => _tasks.removeWhere((item) => item.id == task.id));
    await _saveData();
  }

  Future<void> _editGoals() async {
    final daily = TextEditingController(text: '$_dailyGoal');
    final weekly = TextEditingController(text: '$_weeklyGoal');
    final monthly = TextEditingController(text: '$_monthlyGoal');
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Writing goals'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _goalInput(daily, 'Daily word goal'),
            const SizedBox(height: 10),
            _goalInput(weekly, 'Weekly word goal'),
            const SizedBox(height: 10),
            _goalInput(monthly, 'Monthly word goal'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final values = [daily.text, weekly.text, monthly.text]
                  .map((value) => int.tryParse(value) ?? 0)
                  .toList();
              if (values.any((value) => value <= 0)) return;
              Navigator.pop(context, values);
            },
            child: const Text('Save goals'),
          ),
        ],
      ),
    );
    daily.dispose();
    weekly.dispose();
    monthly.dispose();
    if (result == null) return;
    setState(() {
      _dailyGoal = result[0];
      _weeklyGoal = result[1];
      _monthlyGoal = result[2];
    });
    await _saveData();
  }

  Widget _goalInput(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'words',
        border: const OutlineInputBorder(),
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.day} ${_monthName(date.month)} ${date.year}';

  String _monthName(int month) => const [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][month - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    final tasks = _selectedTasks;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Writing Calendar'),
        actions: [
          IconButton(
            tooltip: 'Writing goals',
            onPressed: _editGoals,
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: 'Choose date',
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Text(
            'Make time for your next chapter.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dateLabel(_selectedDate),
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (DateUtils.isSameDay(_selectedDate, today))
                        const Chip(
                          avatar: Icon(Icons.today, size: 16),
                          label: Text('Today'),
                        )
                      else
                        TextButton(
                          onPressed: () => setState(() => _selectedDate = today),
                          child: const Text('Today'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tasks.length} planned tasks · $_completedToday completed',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: tasks.isEmpty ? 0 : _completedToday / tasks.length,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Your writing goals', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          _goalCard('Daily', _dailyGoal, Icons.wb_sunny_outlined),
          _goalCard('Weekly', _weeklyGoal, Icons.date_range_outlined),
          _goalCard('Monthly', _monthlyGoal, Icons.calendar_view_month_outlined),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Tasks for this day',
                    style: theme.textTheme.titleLarge),
              ),
              TextButton.icon(
                onPressed: () => _showTaskDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (tasks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(Icons.event_note_outlined,
                        size: 42, color: theme.colorScheme.primary),
                    const SizedBox(height: 10),
                    const Text('No writing tasks planned'),
                    const SizedBox(height: 4),
                    Text(
                      'Add a task or set a reminder for this day.',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...tasks.map(_taskTile),
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notifications_active_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reminders are scheduled on this device. Allow notifications when prompted so Writer’s Haven can notify you.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(String label, int goal, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text('$label word goal'),
        trailing: Text(
          '$goal words',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _taskTile(_WritingTask task) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.completed,
          onChanged: (value) => _toggleTask(task, value ?? false),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text([
          if (task.notes.isNotEmpty) task.notes,
          if (task.reminderTime != null)
            'Reminder: ${task.reminderTime!.format(context)}',
          if (task.reminderTime == null) 'No reminder set',
        ].join(' · ')),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _showTaskDialog(existing: task);
            if (value == 'delete') _deleteTask(task);
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _TaskDraft {
  final String title;
  final String notes;
  final DateTime dueDate;
  final TimeOfDay? reminderTime;

  const _TaskDraft({
    required this.title,
    required this.notes,
    required this.dueDate,
    required this.reminderTime,
  });
}

class _WritingTask {
  final String id;
  String title;
  String notes;
  DateTime dueDate;
  TimeOfDay? reminderTime;
  bool completed;

  _WritingTask({
    required this.id,
    required this.title,
    required this.notes,
    required this.dueDate,
    this.reminderTime,
    this.completed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'dueDate': dueDate.toIso8601String(),
        'reminderHour': reminderTime?.hour,
        'reminderMinute': reminderTime?.minute,
        'completed': completed,
      };

  factory _WritingTask.fromJson(Map<String, dynamic> json) {
    final hour = (json['reminderHour'] as num?)?.toInt();
    final minute = (json['reminderMinute'] as num?)?.toInt();
    return _WritingTask(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled task',
      notes: json['notes'] as String? ?? '',
      dueDate: DateTime.tryParse(json['dueDate'] as String? ?? '') ?? DateTime.now(),
      reminderTime: hour == null || minute == null
          ? null
          : TimeOfDay(hour: hour, minute: minute),
      completed: json['completed'] as bool? ?? false,
    );
  }
}
