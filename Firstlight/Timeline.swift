import SwiftUI

struct TimelineScreen: View {
    let alarms: [WakeAlarm]
    @Binding var placing: Bool
    var onCreate: (Int) -> Void
    var onEdit: (WakeAlarm) -> Void
    var onChange: () -> Void

    @State private var touch: CGFloat?
    @State private var focus: Double = 0
    @State private var bulge: Double = 0

    var body: some View {
        GeometryReader { geo in
            let top: CGFloat = 70
            let height = geo.size.height - top - 30
            let toY = { (m: Int) in top + CGFloat(m) / 1440 * height }
            let toMinutes = { (y: CGFloat) in min(1435, max(0, Int((y - top) / height * 1440) / 5 * 5)) }

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard placing else { return }
                            if let touch, toMinutes(touch) != toMinutes(value.location.y) {
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                            touch = value.location.y
                            withAnimation(.interactiveSpring(duration: 0.25)) {
                                focus = Double(value.location.y)
                                bulge = 1
                            }
                        }
                        .onEnded { value in
                            guard placing, touch != nil else { return }
                            touch = nil
                            placing = false
                            withAnimation(.spring(duration: 0.8, bounce: 0.45)) { bulge = 0 }
                            onCreate(toMinutes(value.location.y))
                        })

                Ruler(bulge: bulge, focus: focus, top: top, height: height)
                    .allowsHitTesting(false)

                Group {
                ZStack(alignment: .topLeading) {
                ForEach(alarms) { alarm in
                    AlarmLine(alarm: alarm, onChange: onChange)
                        .offset(x: 74, y: toY(alarm.minutes) - 26)
                        .opacity(touch == nil ? 1 : 0.3)
                        .onTapGesture { onEdit(alarm) }
                        .gesture(DragGesture(minimumDistance: 10, coordinateSpace: .named("timeline"))
                            .onChanged { alarm.setMinutes(toMinutes($0.location.y)) }
                            .onEnded { _ in onChange() })
                }
                }
                }

                if let touch {
                    let m = toMinutes(touch)
                    Rectangle()
                        .fill(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width - 70, height: 1)
                        .offset(x: 70, y: toY(m))
                    Text(clockString(m))
                        .font(.system(size: 68, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 10)
                        .offset(x: 120, y: toY(m) - 88)
                }

                if touch == nil && (placing || alarms.isEmpty) {
                    Text(placing ? "Drag along the timeline to set the time" : "No alarms. Tap + to add one.")
                        .font(.callout.weight(.light))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: geo.size.width)
                        .offset(y: geo.size.height * 0.45)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .coordinateSpace(.named("timeline"))
        }
    }
}

// The hour rail bends outward around the finger and enlarges nearby hours, like the original.
struct Ruler: View, Animatable {
    var bulge: Double
    var focus: Double
    let top: CGFloat
    let height: CGFloat

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(bulge, focus) }
        set { bulge = newValue.first; focus = newValue.second }
    }

    var body: some View {
        Canvas { context, _ in
            var spine = Path()
            for i in 0...96 {
                let y = top + CGFloat(i) / 96 * height
                let d = (Double(y) - focus) / 95
                let k = CGFloat(bulge * exp(-d * d))
                let x = 10 + 46 * k
                if i == 0 { spine.move(to: CGPoint(x: x, y: y)) } else { spine.addLine(to: CGPoint(x: x, y: y)) }
                guard i % 2 == 0 else { continue }
                let hour = i % 4 == 0
                let length: CGFloat = hour ? (i % 24 == 0 ? 18 : 11) : 5
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: y))
                tick.addLine(to: CGPoint(x: x + length, y: y))
                context.stroke(tick, with: .color(.white.opacity(0.35 + 0.6 * k)), lineWidth: hour ? 1 : 0.75)
                if hour {
                    let label = Text("\(i / 4)")
                        .font(.system(size: 11 + 12 * k, weight: .light))
                        .foregroundStyle(.white.opacity(0.5 + 0.5 * k))
                    context.draw(label, at: CGPoint(x: x + length + 5, y: y), anchor: .leading)
                }
            }
            context.stroke(spine, with: .color(.white.opacity(0.2)), lineWidth: 1)
        }
    }
}

struct AlarmLine: View {
    @Bindable var alarm: WakeAlarm
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(clockString(alarm.minutes))
                    .font(.system(size: 30, weight: .thin))
                    .monospacedDigit()
                Text(alarm.summary).font(.caption2).opacity(0.75).lineLimit(1)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: $alarm.enabled).labelsHidden().tint(.white.opacity(0.35))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .frame(width: 280)
        .frost(.capsule)
        .opacity(alarm.enabled ? 1 : 0.55)
        .onChange(of: alarm.enabled) {
            alarm.onceFireDate = nil
            onChange()
        }
    }
}

struct EditorCard: View {
    @Bindable var alarm: WakeAlarm
    var onDelete: () -> Void
    var onDone: () -> Void
    @State private var dragStart: Int?
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                // Drag the time vertically for single-minute changes.
                Text(clockString(alarm.minutes))
                    .font(.system(size: 64, weight: .thin))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: alarm.minutes)
                    .gesture(DragGesture()
                        .onChanged { value in
                            let start = dragStart ?? alarm.minutes
                            dragStart = start
                            let m = ((start - Int(value.translation.height / 6)) % 1440 + 1440) % 1440
                            if m != alarm.minutes {
                                alarm.setMinutes(m)
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                        .onEnded { _ in dragStart = nil })
                Spacer()
                Toggle("", isOn: $alarm.enabled).labelsHidden().tint(.white.opacity(0.35))
            }
            HStack(spacing: 0) {
                ForEach(1...7, id: \.self) { day in
                    let on = alarm.days.contains(day)
                    Button {
                        if on { alarm.days.removeAll { $0 == day } } else { alarm.days.append(day) }
                    } label: {
                        Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                            .font(.subheadline.weight(on ? .medium : .light))
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.white.opacity(on ? 0.3 : 0)))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Rectangle().fill(.white.opacity(0.3)).frame(height: 0.5)
            TextField("", text: $alarm.label, prompt: Text("Label").foregroundStyle(.white.opacity(0.5)))
            Toggle(isOn: $alarm.smartRise) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Rise")
                    Text("A faint sound plays before the alarm. Choose it in settings.")
                        .font(.caption).opacity(0.65)
                }
            }
            .tint(.white.opacity(0.35))
            soundRow("Sound", icon: "music.note", selection: $alarm.sound, options: Sounds.all)
            HStack {
                Button { confirmDelete = true } label: { Image(systemName: "trash").font(.body.weight(.light)) }
                    .confirmationDialog("Delete this alarm?", isPresented: $confirmDelete) {
                        Button("Delete", role: .destructive, action: onDelete)
                    }
                Spacer()
                Button("Done", action: onDone).fontWeight(.medium)
            }
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .tint(.white)
        .padding(24)
        .frost(.rect(cornerRadius: 34))
        .padding(.horizontal, 18)
        .onChange(of: alarm.enabled) { alarm.onceFireDate = nil }
        .onChange(of: alarm.days) { alarm.onceFireDate = nil }
    }

    private func soundRow(_ title: String, icon: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { name in
                Button(Sounds.title(name)) {
                    selection.wrappedValue = name
                    Preview.play(name)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.caption).opacity(0.65)
                    Text(Sounds.title(selection.wrappedValue))
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.caption).opacity(0.5)
            }
        }
    }
}
