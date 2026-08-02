import 'package:flutter/material.dart';

/// Media size caps (free-tier friendly). Referenced by add/edit listing.
const double kMaxImageMb = 5;
const double kMaxVideoMb = 50;

/// Vehicle types an owner can offer slots for.
const List<String> kVehicleTypes = [
  'Car',
  'Motorcycle',
  'SUV',
  'Pickup',
  'Van',
  'Bicycle',
];

const List<String> kWeekdays = [
  'Sat',
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
];

/// Default schedule: open every day 00:00–23:59.
Map<String, dynamic> defaultWeeklySchedule() => {
      for (final d in kWeekdays)
        d: {'open': true, 'from': '00:00', 'to': '23:59'}
    };

/// Repeater that builds a `{VehicleType: count}` capacity map.
class SlotCapacityEditor extends StatelessWidget {
  final Map<String, int> capacity;
  final ValueChanged<Map<String, int>> onChanged;

  const SlotCapacityEditor({
    super.key,
    required this.capacity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unused =
        kVehicleTypes.where((t) => !capacity.containsKey(t)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Slots per Vehicle Type',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Set how many spaces each vehicle type can use.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 12),
        ...capacity.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(e.key)),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: e.value <= 0
                        ? null
                        : () {
                            final m = Map<String, int>.from(capacity);
                            m[e.key] = e.value - 1;
                            onChanged(m);
                          },
                  ),
                  Text('${e.value}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final m = Map<String, int>.from(capacity);
                      m[e.key] = e.value + 1;
                      onChanged(m);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      final m = Map<String, int>.from(capacity)..remove(e.key);
                      onChanged(m);
                    },
                  ),
                ],
              ),
            )),
        if (unused.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: PopupMenuButton<String>(
              onSelected: (type) {
                final m = Map<String, int>.from(capacity);
                m[type] = 1;
                onChanged(m);
              },
              itemBuilder: (_) =>
                  unused.map((t) => PopupMenuItem(value: t, child: Text(t))).toList(),
              child: const Chip(
                avatar: Icon(Icons.add, size: 18),
                label: Text('Add vehicle type'),
              ),
            ),
          ),
      ],
    );
  }
}

/// Instant vs manual-approval booking mode.
class BookingModeSelector extends StatelessWidget {
  final String mode; // 'instant' | 'manual'
  final ValueChanged<String> onChanged;

  const BookingModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Booking Mode',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'instant',
                label: Text('Instant'),
                icon: Icon(Icons.flash_on)),
            ButtonSegment(
                value: 'manual',
                label: Text('Approve'),
                icon: Icon(Icons.how_to_reg)),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        const SizedBox(height: 4),
        Text(
          mode == 'instant'
              ? 'Riders can book immediately.'
              : 'You approve each booking request before it confirms.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}

/// Weekly open/close editor. Produces `{ "Sat": {open, from, to}, ... }`.
class WeeklyScheduleEditor extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const WeeklyScheduleEditor({
    super.key,
    required this.schedule,
    required this.onChanged,
  });

  Future<void> _pickTime(BuildContext context, String day, String key) async {
    final current = (schedule[day]?[key] as String?) ?? '00:00';
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0),
    );
    if (picked == null) return;
    final m = _clone();
    m[day][key] =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    onChanged(m);
  }

  Map<String, dynamic> _clone() => {
        for (final e in schedule.entries)
          e.key: Map<String, dynamic>.from(e.value as Map)
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Availability Schedule',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...kWeekdays.map((day) {
          final d = (schedule[day] as Map?) ?? const {};
          final open = d['open'] as bool? ?? true;
          return Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(day,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Switch(
                value: open,
                onChanged: (v) {
                  final m = _clone();
                  m[day]['open'] = v;
                  onChanged(m);
                },
              ),
              if (open) ...[
                TextButton(
                  onPressed: () => _pickTime(context, day, 'from'),
                  child: Text(d['from'] as String? ?? '00:00'),
                ),
                const Text('–'),
                TextButton(
                  onPressed: () => _pickTime(context, day, 'to'),
                  child: Text(d['to'] as String? ?? '23:59'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text('Closed', style: TextStyle(color: Colors.grey)),
                ),
            ],
          );
        }),
      ],
    );
  }
}
