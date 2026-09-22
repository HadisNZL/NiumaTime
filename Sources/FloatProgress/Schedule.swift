import Foundation

struct ScheduleSnapshot: Equatable {
    enum Phase: Equatable {
        case waiting
        case running
        case finished
    }

    let phase: Phase
    let progress: Double
    let remaining: TimeInterval
    let start: Date
    let end: Date
}

enum Schedule {
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
                progress: 0,
                remaining: effectiveStart.timeIntervalSince(now),
                start: effectiveStart,
                end: effectiveEnd
            )
        }

        if now >= effectiveEnd {
            return ScheduleSnapshot(
                phase: .finished,
                progress: 1,
                remaining: 0,
                start: effectiveStart,
                end: effectiveEnd
            )
        }

        let duration = effectiveEnd.timeIntervalSince(effectiveStart)
        let elapsed = now.timeIntervalSince(effectiveStart)
        return ScheduleSnapshot(
            phase: .running,
            progress: min(max(elapsed / duration, 0), 1),
            remaining: max(effectiveEnd.timeIntervalSince(now), 0),
            start: effectiveStart,
            end: effectiveEnd
        )
    }
}
