import SwiftUI
import SwiftData

struct AlarmEditor: View {
    @Bindable var alarm: WakeAlarm
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack {
            DreamyBackground()
            VStack(spacing: 0) {
                HStack {
                    Button("Delete", role: .destructive) { context.delete(alarm); close() }
                    Spacer()
                    Button("Done") { close() }.fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                HStack(alignment: .top, spacing: 8) {
                    TimelinePicker(minutes: Binding(
                        get: { alarm.hour * 60 + alarm.minute },
                        set: { alarm.hour = $0 / 60; alarm.minute = $0 % 60 }))
                        .frame(width: 150)
                        .padding(.vertical, 12)
                    ScrollView { form }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    let on = alarm.days.contains(day)
                    Button {
                        if on { alarm.days.removeAll { $0 == day } } else { alarm.days.append(day) }
                    } label: {
                        Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                            .font(.footnote)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white.opacity(on ? 0.35 : 0)))
                    }
                }
            }
            TextField("Label", text: $alarm.label)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) { Rectangle().frame(height: 0.5).opacity(0.4) }
            Toggle("Smart Rise", isOn: $alarm.smartRise).tint(.white.opacity(0.4))
            if alarm.smartRise {
                Text("A soft melody starts 30 minutes before the alarm and rises slowly, lifting you out of deep sleep.")
                    .font(.caption).opacity(0.7)
                soundMenu("Melody", selection: $alarm.smartTrack, options: Sounds.smart)
            }
            soundMenu("Alarm", selection: $alarm.sound, options: Sounds.alarm)
        }
        .foregroundStyle(.white)
        .tint(.white)
        .padding(20)
        .glassEffect(.clear, in: .rect(cornerRadius: 26))
    }

    private func soundMenu(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { name in
                Button(name) { selection.wrappedValue = name; Preview.play(name) }
            }
        } label: {
            HStack {
                Image(systemName: "music.note")
                VStack(alignment: .leading) {
                    Text(title).font(.caption).opacity(0.7)
                    Text(selection.wrappedValue)
                }
                Spacer()
            }
        }
    }

    private func close() {
        Preview.stop()
        dismiss()
    }
}

struct TimelinePicker: View {
    @Binding var minutes: Int
    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let y = CGFloat(minutes) / 1440 * h
            ZStack(alignment: .topLeading) {
                ForEach(0..<25) { hour in
                    HStack(spacing: 6) {
                        Rectangle().frame(width: hour % 6 == 0 ? 14 : 7, height: 1)
                        if hour % 3 == 0 { Text("\(hour)").font(.caption2) }
                    }
                    .opacity(0.55)
                    .offset(y: CGFloat(hour) / 24 * h - 6)
                }
                Rectangle().frame(width: 28, height: 1.5).offset(y: y)
                Text(String(format: "%02d:%02d", minutes / 60, minutes % 60))
                    .font(.system(size: dragging ? 46 : 36, weight: .thin))
                    .monospacedDigit()
                    .offset(x: 36, y: y - 26)
                    .animation(.spring(duration: 0.25), value: dragging)
            }
            .foregroundStyle(.white)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragging = true
                    let raw = Int(max(0, min(h, value.location.y)) / h * 1440)
                    let snapped = min(raw / 5 * 5, 1435)
                    if snapped != minutes {
                        minutes = snapped
                        UISelectionFeedbackGenerator().selectionChanged()
                    }
                }
                .onEnded { _ in dragging = false })
        }
    }
}
