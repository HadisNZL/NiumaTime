import SwiftUI

private enum EditableCalendarField: Hashable {
    case year
    case month
}

struct CalendarPopoverView: View {
    @ObservedObject var model: ProgressModel

    @State private var month: CalendarMonth
    @State private var selectedDate: Date
    @State private var nextOfficialRestDay: Date?
    @State private var editingCalendarField: EditableCalendarField?
    @State private var yearDraft = ""
    @State private var monthDraft = ""
    @FocusState private var focusedCalendarField: EditableCalendarField?

    private let restColor = Color(red: 0.92, green: 0.27, blue: 0.20)
    private let adjustedWorkColor = Color(red: 0.145, green: 0.388, blue: 0.922)

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private var weekdays: [String] {
        model.calendarFirstWeekday == 1
            ? ["日", "一", "二", "三", "四", "五", "六"]
            : ["一", "二", "三", "四", "五", "六", "日"]
    }

    init(model: ProgressModel) {
        self.model = model
        let today = Calendar.current.startOfDay(for: model.now)
        _month = State(initialValue: CalendarMonth.make(
            containing: today,
            firstWeekday: model.calendarFirstWeekday
        ))
        _selectedDate = State(initialValue: today)
        _nextOfficialRestDay = State(initialValue: CalendarMonth.nextOfficialRestDay(after: today))
    }

    var body: some View {
        VStack(spacing: 11) {
            header
            if model.showMonthSummary {
                monthSummary
            }
            weekdayHeader
            calendarGrid
            selectedDayCard
        }
        .padding(14)
        .frame(width: 410)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .contentShape(Rectangle())
                .onTapGesture {
                    finishCalendarEditingIfNeeded()
                }
        }
        .onChange(of: dayKey(model.now)) { oldValue, newValue in
            guard oldValue != newValue else { return }
            nextOfficialRestDay = CalendarMonth.nextOfficialRestDay(after: model.now)
            if Calendar.current.isDate(month.monthStart, equalTo: model.now, toGranularity: .month) {
                month = CalendarMonth.make(
                    containing: model.now,
                    firstWeekday: model.calendarFirstWeekday
                )
                selectedDate = Calendar.current.startOfDay(for: model.now)
            }
        }
        .onChange(of: model.calendarFirstWeekday) { _, _ in
            month = CalendarMonth.make(
                containing: month.monthStart,
                firstWeekday: model.calendarFirstWeekday
            )
        }
        .onChange(of: focusedCalendarField) { oldValue, newValue in
            if let oldValue, oldValue != newValue {
                commitCalendarField(oldValue)
            }
            if newValue == nil, editingCalendarField == oldValue {
                editingCalendarField = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                finishCalendarEditingIfNeeded()
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canMoveMonth(by: -1))
            .help("上个月")

            Spacer()
            HStack(spacing: 2) {
                editableDatePart(.year)
                Text("年")
                    .onTapGesture { finishCalendarEditingIfNeeded() }
                editableDatePart(.month)
                Text("月")
                    .onTapGesture { finishCalendarEditingIfNeeded() }
            }
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .frame(height: 34)
            Spacer()

            Button {
                finishCalendarEditingIfNeeded()
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canMoveMonth(by: 1))
            .help("下个月")

            Button {
                finishCalendarEditingIfNeeded()
                returnToToday()
            } label: {
                Text("今天")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(model.calendarAccentSwiftUIColor)
                    .frame(width: 34, height: 34)
                    .background(model.calendarAccentSwiftUIColor.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .help("返回今天")
        }
    }

    @ViewBuilder
    private func editableDatePart(_ field: EditableCalendarField) -> some View {
        if editingCalendarField == field {
            TextField("", text: field == .year ? $yearDraft : $monthDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .frame(width: field == .year ? 54 : 30, height: 27)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                .focused($focusedCalendarField, equals: field)
                .onSubmit { finishCalendarEditing(field) }
                .onChange(of: field == .year ? yearDraft : monthDraft) { _, value in
                    sanitizeDraft(value, for: field)
                }
        } else {
            Button {
                beginCalendarEditing(field)
            } label: {
                Text(verbatim: field == .year ? String(displayedYear) : String(displayedMonth))
                    .monospacedDigit()
                    .padding(.horizontal, 2)
                    .frame(minWidth: field == .year ? 46 : 18, minHeight: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(field == .year ? "单击输入年份（1900–2100）" : "单击输入月份（1–12）")
        }
    }

    private var monthSummary: some View {
        HStack(spacing: 8) {
            summaryChip(title: "本月上班", value: "\(month.workdayCount) 天", color: model.calendarAccentSwiftUIColor)
            summaryChip(title: "本月休息", value: "\(month.restDayCount) 天", color: restColor)
            if let nextOfficialRestDay {
                summaryChip(
                    title: nextRestTitle(nextOfficialRestDay),
                    value: nextRestDistance(nextOfficialRestDay),
                    color: restColor
                )
            }
        }
        .onTapGesture { finishCalendarEditingIfNeeded() }
    }

    private func summaryChip(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.primary.opacity(0.74))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(weekdays.enumerated()), id: \.offset) { index, value in
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(value == "六" || value == "日" ? Color.red.opacity(0.88) : Color.primary.opacity(0.68))
                    .frame(maxWidth: .infinity)
            }
        }
        .onTapGesture { finishCalendarEditingIfNeeded() }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(month.days) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ item: CalendarDay) -> some View {
        let isSelected = Calendar.current.isDate(item.date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDate(item.date, inSameDayAs: model.now)
        let isRest = !item.workdayKind.isWorkday
        let regularDayColor = Color.primary.opacity(item.isInDisplayedMonth ? 0.96 : 0.9)
        let regularDetailColor = Color.primary.opacity(item.isInDisplayedMonth ? 0.74 : 0.66)

        return Button {
            finishCalendarEditingIfNeeded()
            selectedDate = item.date
        } label: {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(isSelected ? model.calendarAccentSwiftUIColor.opacity(0.14) : Color.clear)

                VStack(spacing: 2) {
                    Text("\(item.day)")
                        .font(.system(size: isToday ? 14.5 : 13.5, weight: isToday ? .heavy : .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isToday ? model.calendarAccentSwiftUIColor : (isRest ? restColor : regularDayColor))
                    Text(secondaryText(for: item))
                        .font(.system(
                            size: item.festival != nil || item.solarTerm != nil ? 10 : 9.5,
                            weight: item.festival != nil || item.solarTerm != nil ? .bold : .medium
                        ))
                        .foregroundStyle(item.festival != nil ? restColor : (item.solarTerm != nil ? model.calendarAccentSwiftUIColor : regularDetailColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if model.showWorkdayBadges {
                    if item.workdayKind == .adjustedWorkday {
                        badge("班", color: adjustedWorkColor)
                    } else if item.workdayKind == .publicHoliday {
                        badge("休", color: .red)
                    }
                }
            }
            .frame(height: 45)
            .contentShape(RoundedRectangle(cornerRadius: 9))
            .opacity(item.isInDisplayedMonth ? 1 : 0.48)
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 8.5, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 14, height: 14)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
            .offset(x: 2, y: -2)
    }

    private var selectedDayCard: some View {
        let kind = ChinaWorkdayCalendar.kind(for: selectedDate)
        let isToday = Calendar.current.isDate(selectedDate, inSameDayAs: model.now)
        let detail = selectedCalendarDay

        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(model.calendarAccentSwiftUIColor.opacity(0.14))
                VStack(spacing: -1) {
                    Text(selectedDate, format: .dateTime.month(.abbreviated))
                        .font(.system(size: 10.5, weight: .bold))
                    Text(selectedDate, format: .dateTime.day())
                        .font(.title2.bold().monospacedDigit())
                }
                .foregroundStyle(model.calendarAccentSwiftUIColor)
            }
            .frame(width: 50, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(selectedDateTitle) \(selectedDate.formatted(.dateTime.weekday(.wide)))（第\(selectedWeekOfYear)周）")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.82))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let festival = detail?.festival ?? detail?.solarTerm {
                        Text(festival)
                            .foregroundStyle(detail?.festival != nil ? restColor : model.calendarAccentSwiftUIColor)
                    }
                    Text(ChineseCalendarText.fullText(for: selectedDate))
                        .foregroundStyle(Color.primary.opacity(0.78))
                }
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .lineLimit(1)

                if !isToday || model.countdownEnabled {
                    Text(isToday ? todayDetail : scheduleDetail(for: kind))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(kind.isWorkday ? model.calendarAccentSwiftUIColor : restColor)
                        .lineLimit(1)
                }

                Text(isToday ? model.workdayStatusText : kind.title)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.primary.opacity(0.78))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(.quaternary.opacity(0.40), in: RoundedRectangle(cornerRadius: 12))
        .onTapGesture { finishCalendarEditingIfNeeded() }
    }

    private var selectedDateTitle: String {
        let values = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        return String(format: "%04d年%02d月%02d日", values.year ?? 0, values.month ?? 0, values.day ?? 0)
    }

    private var selectedWeekOfYear: Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = Calendar.current.timeZone
        return calendar.component(.weekOfYear, from: selectedDate)
    }

    private var selectedCalendarDay: CalendarDay? {
        month.days.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var todayDetail: String {
        if model.isRestingToday { return model.restStatusText }
        return model.calendarStatusText
    }

    private func scheduleDetail(for kind: ChinaWorkdayKind) -> String {
        guard kind.isWorkday else { return "全天休息" }
        return "工作计划 \(clock(model.startMinutes))–\(clock(model.endMinutes))"
    }

    private func moveMonth(by value: Int) {
        guard let target = Calendar.current.date(byAdding: .month, value: value, to: month.monthStart) else { return }
        let targetYear = Calendar.current.component(.year, from: target)
        guard CalendarMonth.supportedYears.contains(targetYear) else { return }
        month = CalendarMonth.make(
            containing: target,
            firstWeekday: model.calendarFirstWeekday
        )
        selectedDate = CalendarMonth.selectionDate(
            forDisplayedMonth: month.monthStart,
            today: model.now
        )
    }

    private func returnToToday() {
        selectedDate = Calendar.current.startOfDay(for: model.now)
        month = CalendarMonth.make(
            containing: model.now,
            firstWeekday: model.calendarFirstWeekday
        )
    }

    private var displayedYear: Int {
        Calendar.current.component(.year, from: month.monthStart)
    }

    private var displayedMonth: Int {
        Calendar.current.component(.month, from: month.monthStart)
    }

    private func beginCalendarEditing(_ field: EditableCalendarField) {
        if let currentField = editingCalendarField, currentField != field {
            commitCalendarField(currentField)
        }
        yearDraft = String(displayedYear)
        monthDraft = String(displayedMonth)
        editingCalendarField = field
        Task { @MainActor in
            focusedCalendarField = field
        }
    }

    private func sanitizeDraft(_ value: String, for field: EditableCalendarField) {
        let limit = field == .year ? 4 : 2
        let sanitized = String(value.filter(\.isNumber).prefix(limit))
        if field == .year, yearDraft != sanitized {
            yearDraft = sanitized
        } else if field == .month, monthDraft != sanitized {
            monthDraft = sanitized
        }
    }

    private func finishCalendarEditing(_ field: EditableCalendarField) {
        commitCalendarField(field)
        editingCalendarField = nil
        focusedCalendarField = nil
    }

    private func finishCalendarEditingIfNeeded() {
        guard let field = editingCalendarField else { return }
        finishCalendarEditing(field)
    }

    private func commitCalendarField(_ field: EditableCalendarField) {
        let requestedYear = field == .year ? Int(yearDraft) : displayedYear
        let requestedMonth = field == .month ? Int(monthDraft) : displayedMonth
        guard let requestedYear,
              let requestedMonth,
              CalendarMonth.supportedYears.contains(requestedYear),
              (1...12).contains(requestedMonth) else {
            yearDraft = String(displayedYear)
            monthDraft = String(displayedMonth)
            return
        }
        setDisplayedMonth(year: requestedYear, month: requestedMonth)
    }

    private func setDisplayedMonth(year: Int, month value: Int) {
        guard let target = CalendarMonth.monthStart(year: year, month: value) else { return }
        month = CalendarMonth.make(
            containing: target,
            firstWeekday: model.calendarFirstWeekday
        )
        selectedDate = CalendarMonth.selectionDate(
            forDisplayedMonth: month.monthStart,
            today: model.now
        )
    }

    private func canMoveMonth(by value: Int) -> Bool {
        guard let target = Calendar.current.date(byAdding: .month, value: value, to: month.monthStart) else {
            return false
        }
        return CalendarMonth.supportedYears.contains(Calendar.current.component(.year, from: target))
    }

    private func nextRestTitle(_ date: Date) -> String {
        let lunar = ChineseCalendarText.lunarText(for: date)
        return ChineseCalendarText.festival(for: date, lunarMonth: lunar.month, lunarDay: lunar.day)
            ?? SolarTerms.name(for: date)
            ?? "下个法定休息"
    }

    private func nextRestDistance(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: model.now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: date)).day ?? 0
        if days == 0 { return "今天" }
        return "还有 \(days) 天"
    }

    private func clock(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    private func secondaryText(for day: CalendarDay) -> String {
        if let festival = day.festival { return festival }
        if let solarTerm = day.solarTerm { return solarTerm }
        return model.showLunarDetails ? day.lunarText : ""
    }

    private func dayKey(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}
