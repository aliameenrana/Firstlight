import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Query(sort: [SortDescriptor(\WakeAlarm.hour), SortDescriptor(\WakeAlarm.minute)]) private var alarms: [WakeAlarm]
    @State private var editing: WakeAlarm?

    var body: some View {
        ZStack {
            DreamyBackground()
            ScrollView {
                VStack(spacing: 14) {
                    ClockFace().padding(.vertical, 48)
                    ForEach(alarms) { alarm in
                        AlarmCard(alarm: alarm, onChange: sync)
                            .onTapGesture { editing = alarm }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }
            VStack {
                Spacer()
                Button {
                    let alarm = WakeAlarm()
                    context.insert(alarm)
                    editing = alarm
                } label: {
                    Image(systemName: "plus").font(.title2.weight(.light)).foregroundStyle(.white).frame(width: 64, height: 64)
                }
                .glassEffect(.clear.interactive(), in: .circle)
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(item: $editing, onDismiss: sync) { AlarmEditor(alarm: $0) }
        .task { sync() }
        .onChange(of: phase) { sync() }
    }

    private func sync() {
        let list = alarms
        SmartRise.shared.arm(list.map(\.plan))
        Task { await Scheduler.sync(list) }
    }
}

struct ClockFace: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                        .font(.system(size: 100, weight: .ultraLight))
                    Text(context.date, format: .dateTime.second(.twoDigits))
                        .font(.system(size: 30, weight: .thin))
                }
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.4), value: context.date)
                Text(context.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.title3.weight(.light))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 12)
        }
    }
}

struct AlarmCard: View {
    @Bindable var alarm: WakeAlarm
    var onChange: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%02d:%02d", alarm.hour, alarm.minute)).font(.system(size: 46, weight: .thin))
                Text(subtitle).font(.footnote).opacity(0.75)
            }
            Spacer()
            Toggle("", isOn: $alarm.enabled).labelsHidden().tint(.white.opacity(0.4))
        }
        .foregroundStyle(.white)
        .padding(20)
        .glassEffect(.clear, in: .rect(cornerRadius: 26))
        .opacity(alarm.enabled ? 1 : 0.6)
        .onChange(of: alarm.enabled) { onChange() }
    }

    private var subtitle: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let days = alarm.days.isEmpty ? "Once" : alarm.days.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
        return [alarm.label, days, alarm.smartRise ? "Smart Rise" : nil].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")
    }
}
