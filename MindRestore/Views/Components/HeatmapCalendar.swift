import SwiftUI

struct HeatmapCalendarView: View {
    let trainingDays: Set<Date>
    private let calendar = Calendar.current

    private var currentMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date.now)) ?? Date.now
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var trainedThisMonth: Int {
        trainingDays.filter { $0 >= currentMonth }.count
    }

    /// Days in the current month, padded with nils for weekday alignment
    private var calendarDays: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: currentMonth) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: currentMonth)
        // Convert to Monday=0 index (Sunday=6)
        let leadingBlanks = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: currentMonth) {
                days.append(date)
            }
        }
        // Pad trailing to fill last row
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(monthName)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(trainedThisMonth) \(trainedThisMonth == 1 ? "day" : "days") trained")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Weekday labels
            HStack(spacing: 0) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let isTrained = trainingDays.contains(calendar.startOfDay(for: date))
                        let isToday = calendar.isDateInToday(date)
                        let isFuture = date > Date.now

                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(cellColor(isTrained: isTrained, isToday: isToday, isFuture: isFuture))
                                .aspectRatio(1, contentMode: .fit)

                            Text("\(calendar.component(.day, from: date))")
                                .font(.system(size: 10, weight: isTrained ? .bold : .regular, design: .rounded))
                                .foregroundStyle(isTrained ? .white : isFuture ? .secondary.opacity(0.3) : .secondary)
                        }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }

            // Legend
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 10, height: 10)
                    Text("No activity")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.accent)
                        .frame(width: 10, height: 10)
                    Text("Trained")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func cellColor(isTrained: Bool, isToday: Bool, isFuture: Bool) -> Color {
        if isTrained {
            return AppColors.accent
        } else if isToday {
            return AppColors.accent.opacity(0.2)
        } else if isFuture {
            return Color.gray.opacity(0.06)
        }
        return Color.gray.opacity(0.12)
    }
}
