class AvailabilityRule {
  const AvailabilityRule({
    required this.weekday,
    required this.startMinute,
    required this.endMinute,
  });
  final int weekday;
  final int startMinute;
  final int endMinute;

  AvailabilityRule copyWith({int? startMinute, int? endMinute}) =>
      AvailabilityRule(
        weekday: weekday,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
      );
}

class ScheduleBlock {
  const ScheduleBlock({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.reason,
  });
  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;
}

class ProviderSchedule {
  const ProviderSchedule({
    required this.timeZone,
    required this.minimumNoticeMinutes,
    required this.bookingHorizonDays,
    required this.bufferMinutes,
    required this.slotIntervalMinutes,
    required this.version,
    required this.rules,
    required this.blocks,
  });
  final String timeZone;
  final int minimumNoticeMinutes;
  final int bookingHorizonDays;
  final int bufferMinutes;
  final int slotIntervalMinutes;
  final int version;
  final List<AvailabilityRule> rules;
  final List<ScheduleBlock> blocks;

  ProviderSchedule copyWith({
    int? minimumNoticeMinutes,
    int? bookingHorizonDays,
    int? bufferMinutes,
    int? slotIntervalMinutes,
    int? version,
    List<AvailabilityRule>? rules,
    List<ScheduleBlock>? blocks,
  }) => ProviderSchedule(
    timeZone: timeZone,
    minimumNoticeMinutes: minimumNoticeMinutes ?? this.minimumNoticeMinutes,
    bookingHorizonDays: bookingHorizonDays ?? this.bookingHorizonDays,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    slotIntervalMinutes: slotIntervalMinutes ?? this.slotIntervalMinutes,
    version: version ?? this.version,
    rules: rules ?? this.rules,
    blocks: blocks ?? this.blocks,
  );
}

class ScheduleBlockDraft {
  const ScheduleBlockDraft({
    required this.startsAt,
    required this.endsAt,
    required this.reason,
  });
  final DateTime startsAt;
  final DateTime endsAt;
  final String reason;
}

class AvailableSlotPage {
  const AvailableSlotPage({required this.slots, this.nextCursor});
  final List<DateTime> slots;
  final String? nextCursor;
}
