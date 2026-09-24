import Foundation

struct ScheduleSnapshot: Equatable {
    enum Phase: Equatable {
        case waiting
        case running
        case finished
    }

    let phase: Phase
    let remaining: TimeInterval
}

enum Schedule {
    /// The civil date that owns the current shift. For an overnight plan,
    /// times before its end belong to the shift that started the previous day.
    static func workDate(
        for now: Date,
        startMinutes: Int,
        endMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        let dayStart = calendar.startOfDay(for: now)
        guard endMinutes <= startMinutes else { return dayStart }

        let components = calendar.dateComponents([.hour, .minute], from: now)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        guard currentMinutes < endMinutes else { return dayStart }
        return calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart
    }

    static func snapshot(
        now: Date,
        startMinutes: Int,
        endMinutes: Int,
        calendar: Calendar = .current
    ) -> ScheduleSnapshot {
        let dayStart = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .minute, value: startMinutes, to: dayStart) ?? dayStart
        var end = calendar.date(byAdding: .minute, value: endMinutes, to: dayStart) ?? dayStart

        // A smaller/equal end time represents an overnight interval, e.g. 22:00–06:00.
        if endMinutes <= startMinutes {
            end = calendar.date(byAdding: .day, value: 1, to: end) ?? end
        }

        var effectiveStart = start
        var effectiveEnd = end

        if endMinutes <= startMinutes,
           let previousStart = calendar.date(byAdding: .day, value: -1, to: start),
           now < start,
           now >= previousStart {
            effectiveStart = previousStart
            effectiveEnd = calendar.date(byAdding: .day, value: -1, to: end) ?? end
        }

        if now < effectiveStart {
            return ScheduleSnapshot(
                phase: .waiting,
                remaining: effectiveStart.timeIntervalSince(now)
            )
        }

        if now >= effectiveEnd {
            return ScheduleSnapshot(
                phase: .finished,
                remaining: 0
            )
        }

        return ScheduleSnapshot(
            phase: .running,
            remaining: max(effectiveEnd.timeIntervalSince(now), 0)
        )
    }

    /// The next instant at which the schedule phase can change. Keeping this
    /// calculation separate lets the app sleep between meaningful updates.
    static func nextTransition(
        after now: Date,
        startMinutes: Int,
        endMinutes: Int,
        calendar: Calendar = .current
    ) -> Date {
        let dayStart = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .minute, value: startMinutes, to: dayStart) ?? dayStart
        let end = calendar.date(byAdding: .minute, value: endMinutes, to: dayStart) ?? dayStart

        if endMinutes > startMinutes {
            if now < start { return start }
            if now < end { return end }
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
            return calendar.date(byAdding: .minute, value: startMinutes, to: tomorrow) ?? tomorrow
        }

        if now < end { return end }
        if now < start { return start }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        return calendar.date(byAdding: .minute, value: endMinutes, to: tomorrow) ?? tomorrow
    }
}
