import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Query(sort: [SortDescriptor(\WakeAlarm.hour), SortDescriptor(\WakeAlarm.minute)]) private var alarms: [WakeAlarm]
    @State private var page = ProcessInfo.processInfo.arguments.contains("-alarms") ? 1 : 0
    @State private var editing: WakeAlarm?
    @State private var placing = false
    @State private var showTheme = false

    var body: some View {
        ZStack {
            DreamyBackground()
            if page == 0 {
                ClockPage(next: alarms.filter(\.enabled).compactMap { $0.plan.nextFire() }.min(), onShowAlarms: { page = 1 })
                    .transition(.opacity)
            } else {
                TimelineScreen(alarms: alarms, placing: $placing, onCreate: create, onEdit: open, onChange: sync)
                    .transition(.opacity)
            }
            Group {
                VStack {
                    ZStack {
                        HStack(spacing: 0) {
                            tab(0, "clock")
                            tab(1, "alarm")
                        }
                        .frost(.capsule)
                        HStack {
                            Button { showTheme = true } label: {
                                Image(systemName: "paintpalette")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                            }
                            .frost(.circle, interactive: true)
                            Spacer()
                            Button {
                                page = 1
                                withAnimation(.spring(duration: 0.35)) { placing.toggle() }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .light))
                                    .rotationEffect(.degrees(placing ? 45 : 0))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                            }
                            .frost(.circle, interactive: true)
                        }
                        .padding(.horizontal, 16)
                    }
                    Spacer()
                }
            }
            if let editing {
                Color.black.opacity(0.25).ignoresSafeArea()
                    .onTapGesture(perform: close)
                    .transition(.opacity)
                EditorCard(alarm: editing, onDelete: { context.delete(editing); close() }, onDone: close)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .global).onEnded { Touch.shared.pop = ($0.location, .now) })
        .sheet(isPresented: $showTheme) { ThemeView() }
        .animation(.easeInOut(duration: 0.35), value: page)
        .task { sync() }
        .onChange(of: phase) { sync() }
    }

    private func tab(_ index: Int, _ icon: String) -> some View {
        Button { page = index; placing = false } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.white.opacity(page == index ? 1 : 0.45))
                .frame(width: 58, height: 40)
        }
    }

    private func create(_ minutes: Int) {
        let alarm = WakeAlarm()
        alarm.setMinutes(minutes)
        context.insert(alarm)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        open(alarm)
    }

    private func open(_ alarm: WakeAlarm) {
        withAnimation(.spring(duration: 0.45, bounce: 0.25)) { editing = alarm }
    }

    private func close() {
        Preview.stop()
        withAnimation(.spring(duration: 0.4)) { editing = nil }
        sync()
    }

    private func sync() {
        let list = alarms
        SmartRise.shared.arm(list.map(\.plan))
        Task { await Scheduler.sync(list) }
    }
}

struct ClockPage: View {
    let next: Date?
    var onShowAlarms: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                            .font(.system(size: 112, weight: .ultraLight))
                        Text(context.date, format: .dateTime.second(.twoDigits))
                            .font(.system(size: 32, weight: .thin))
                    }
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.4), value: context.date)
                    Text(context.date, format: .dateTime.weekday(.wide).month().day())
                        .font(.title3.weight(.light))
                        .opacity(0.85)
                }
            }
            if let next {
                Label { Text(next, format: .dateTime.weekday(.abbreviated).hour().minute()) } icon: { Image(systemName: "alarm") }
                    .font(.footnote.weight(.light))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .frost(.capsule, interactive: true)
                    .contentShape(.capsule)
                    .onTapGesture(perform: onShowAlarms)
            }
            Spacer()
            Spacer()
        }
        .foregroundStyle(.white)
    }
}
