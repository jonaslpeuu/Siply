//
//  ContentView.swift
//  Siply
//
//  Created by Jonas Hoppe on 27.09.25.
//

import SwiftUI
import UserNotifications

// MARK: - Models
struct IntakeEntry: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let amount: Int
}

enum Tab: CaseIterable, Hashable { case home, calendar, reminders }

// Local notification helper
struct NotificationManager {
    static func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
    }

    static func scheduleRepeatingReminder(intervalMinutes: Int, currentIntake: Int = 0, goal: Int = 2000) async {
        guard intervalMinutes >= 1 else { return }
        let center = UNUserNotificationCenter.current()

        // Remove existing to avoid duplicates
        center.removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()

        // Random motivational message
        let message = MotivationalMessages.random()
        content.title = String(localized: "notification_title", defaultValue: "Stay Hydrated!")
        content.body = message
        content.sound = .default
        content.categoryIdentifier = "WATER_REMINDER"

        // Custom data for notification
        let progress = goal > 0 ? Int((Double(currentIntake) / Double(goal)) * 100) : 0
        content.userInfo = [
            "currentIntake": currentIntake,
            "goal": goal,
            "progress": progress
        ]

        // Badge shows progress percentage
        content.badge = NSNumber(value: progress)

        let seconds = TimeInterval(intervalMinutes * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: true)

        let request = UNNotificationRequest(identifier: "siply.water.reminder", content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()

        // Quick actions in notifications
        let addSmallAction = UNNotificationAction(
            identifier: "ADD_250",
            title: String(localized: "notification_action_small", defaultValue: "Add 250ml"),
            options: []
        )

        let addMediumAction = UNNotificationAction(
            identifier: "ADD_500",
            title: String(localized: "notification_action_medium", defaultValue: "Add 500ml"),
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: String(localized: "notification_action_snooze", defaultValue: "Remind me later"),
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "WATER_REMINDER",
            actions: [addSmallAction, addMediumAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([category])
    }
}

// A simple sine-wave shape that we can use to visualize water inside a circle.
struct WaveShape: Shape {
    var progress: CGFloat   // 0.0 - 1.0 (fill level)
    var amplitude: CGFloat  // wave height in points
    var phase: CGFloat      // animation phase

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, phase) }
        set {
            progress = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let baseline = rect.height * (1 - progress)
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: baseline))

        let wavelength = width / 1.2 // one gentle wave
        let twoPi = CGFloat.pi * 2

        var x: CGFloat = 0
        while x <= width {
            let relative = x / wavelength
            let y = baseline + sin(relative * twoPi + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 1
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

struct WaterWaves: View {
    var progress: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase1 = CGFloat(t * 1.2)
            let phase2 = CGFloat(t * 1.6 + .pi / 2)

            ZStack {
                // Back wave (softer, slightly blurred)
                WaveShape(progress: progress, amplitude: 8, phase: phase2)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 1.5)
                    .opacity(0.9)

                // Front wave (crisper)
                WaveShape(progress: progress, amplitude: 12, phase: phase1)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(0.95)

                // Subtle highlight line along the wave crest
                WaveShape(progress: progress, amplitude: 12, phase: phase1)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
                    .blendMode(.plusLighter)
                    .opacity(0.6)
            }
        }
    }
}

struct ContentView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    // Core state
    @State private var goal: Int = 2000 // ml
    @State private var intake: Int = 0 // ml
    @State private var selectedDate: Date = Date()
    // Removed: @State private var phase: CGFloat = 0 // wave phase for animation
    @State private var history: [IntakeEntry] = []
    @AppStorage("user_name") private var userName: String = ""
    @State private var showDebugMenu: Bool = false
    @State private var suppressSettingsTap: Bool = false
    @State private var didReachGoal: Bool = false
    @State private var showCelebration: Bool = false

    // UI state
    @State private var selectedTab: Tab = .home
    @State private var showSettings: Bool = false
    @State private var showOnboarding: Bool = false
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding: Bool = false

    // How much to add per tap (can be tweaked later or made configurable)
    @AppStorage("step_ml") private var step: Int = 150
    @AppStorage("reminders_enabled") private var remindersEnabled: Bool = false
    @AppStorage("reminder_interval_minutes") private var reminderIntervalMinutes: Int = 60

    var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(1, CGFloat(intake) / CGFloat(goal))
    }

    var body: some View {
        ZStack {
            // Soft blue gradient background
            LinearGradient(colors: [Color(red: 0.84, green: 0.93, blue: 1.0), Color(red: 0.73, green: 0.88, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    Group { content }
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: selectedTab)
                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .safeAreaPadding(.top)
            .safeAreaPadding(.bottom, 120)
            .animation(nil, value: selectedTab)
        }
        .preferredColorScheme(.light)
        .safeAreaInset(edge: .bottom) { bottomBar.padding(.bottom, 8) }
        .onAppear {
            if !hasSeenOnboarding {
                showOnboarding = true
            }
            // Setup notification categories
            NotificationManager.setupNotificationCategories()

            // Removed animation block that sets phase
            Task { @MainActor in
                if remindersEnabled {
                    let granted = await NotificationManager.requestAuthorization()
                    if granted {
                        await NotificationManager.scheduleRepeatingReminder(
                            intervalMinutes: reminderIntervalMinutes,
                            currentIntake: intake,
                            goal: goal
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                userName: $userName,
                goal: $goal,
                remindersEnabled: $remindersEnabled,
                reminderIntervalMinutes: $reminderIntervalMinutes,
                onFinish: {
                    hasSeenOnboarding = true
                    showOnboarding = false
                    if remindersEnabled {
                        Task { @MainActor in
                            let granted = await NotificationManager.requestAuthorization()
                            if granted {
                                await NotificationManager.scheduleRepeatingReminder(intervalMinutes: reminderIntervalMinutes)
                            }
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showDebugMenu) {
            DebugMenuView(
                resetAction: {
                    // Clear model & UI state
                    intake = 0
                    history.removeAll()
                    // Reset onboarding flag so it shows again
                    hasSeenOnboarding = false
                    // Optionally disable reminders
                    remindersEnabled = false
                    // Close debug menu and show onboarding
                    showDebugMenu = false
                    showOnboarding = true
                },
                cancelAction: { showDebugMenu = false }
            )
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack(alignment: .center) {
            Text(String(format: String(localized: "hello_name", defaultValue: "Hello %@"), userName.isEmpty ? "Mike" : userName))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
            Spacer()
            Button {
                if suppressSettingsTap {
                    suppressSettingsTap = false
                } else {
                    showSettings = true
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .padding(10)
                    .background {
                        if reduceTransparency {
                            Circle().fill(Color.white.opacity(0.2))
                        } else {
                            Circle().fill(Material.ultraThin)
                        }
                    }
            }
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            .accessibilityLabel(LocalizedStringKey(String(localized: "settings_title", defaultValue: "Settings")))
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 3.0, maximumDistance: 50)
                    .onEnded { _ in
                        suppressSettingsTap = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showDebugMenu = true
                    }
            )
        }
    }

    // MARK: - Main content switcher
    @ViewBuilder private var content: some View {
        switch selectedTab {
        case .home:
            VStack(spacing: 24) {
                progressCapsule
                waterGauge
                quickAddRow
            }
        case .calendar:
            calendarView
        case .reminders:
            remindersView
        }
    }

    // MARK: - Top progress capsule with reset
    private var progressCapsule: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(localized: "progress_title", defaultValue: "Progress"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(round(progress * 100)))%")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    withAnimation(.spring) {
                        intake = 0
                        history.removeAll()
                        didReachGoal = false
                        showCelebration = false
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(6)
                        .background {
                            if reduceTransparency {
                                Circle().fill(Color.white.opacity(0.15))
                            } else {
                                Circle().fill(Material.ultraThin)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey(String(localized: "reset_today", defaultValue: "Reset today")))
            }

            ZStack(alignment: .leading) {
                Group {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Material.ultraThin)
                    }
                }
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    let fillWidth = max(0, width * progress)

                    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.95), Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth, height: height)
                        .animation(.spring(response: 0.35, dampingFraction: 0.9), value: progress)
                }
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .frame(height: 18)

            HStack {
                Text("\(intake) ml")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(goal) ml")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Material.ultraThin)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard horizontal < -40, abs(vertical) < 30 else { return }
                    removeWater(amount: 200)
                }
        )
    }

    // MARK: - Water gauge (tap to add water)
    private var waterGauge: some View {
        VStack(spacing: 12) {
            ZStack {
                // Outer circle
                Circle()
                    .stroke(.white.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 260, height: 260)
                    .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 2)

                // Water fill with animated wave
                Circle()
                    .fill(Color.clear)
                    .frame(width: 260, height: 260)
                    .overlay(
                        Group {
                            if progress > 0 {
                                WaterWaves(progress: progress)
                            }
                        }
                    )
                    .clipShape(Circle())

                VStack(spacing: 4) {
                    Text(String(localized: "tap_to_add_water", defaultValue: "Tap to Add Water"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if showCelebration {
                    CelebrationView()
                        .frame(width: 260, height: 260)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Circle())
            .onTapGesture { addWater() }
            .accessibilityAddTraits(.isButton)

            HStack(spacing: 6) {
                Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6)
                Circle().fill(Color.white.opacity(0.35)).frame(width: 6, height: 6)
                Circle().fill(Color.white.opacity(0.35)).frame(width: 6, height: 6)
            }
            .padding(.top, 6)
        }
    }

    // Quick add buttons under the gauge
    private var quickAddRow: some View {
        HStack(spacing: 16) {
            Button(action: { addWater(amount: 250) }) {
                labelCapsule(
                    text: "+250 ml",
                    systemImage: "drop.fill",
                    gradientColors: [Color.blue.opacity(0.9), Color.cyan]
                )
            }
            Button(action: { addWater(amount: 500) }) {
                labelCapsule(
                    text: "+500 ml",
                    systemImage: "drop.circle.fill",
                    gradientColors: [Color.cyan, Color.blue.opacity(0.9)]
                )
            }
        }
    }

    private func labelCapsule(text: String, systemImage: String, gradientColors: [Color]) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background {
            if reduceTransparency {
                Capsule().fill(Color.white.opacity(0.18))
            } else {
                Capsule().fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .overlay(
            Capsule().stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .foregroundStyle(reduceTransparency ? Color.primary : Color.white)
        .shadow(color: Color.black.opacity(reduceTransparency ? 0 : 0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Stats

    private func dailyTotal(on date: Date) -> Int {
        return entries(on: date).reduce(0) { $0 + $1.amount }
    }

    private var calendarView: some View {
        VStack(spacing: 16) {
            progressCapsule

            // Kalender & Tagesübersicht
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "calendar_title", defaultValue: "Calendar"))
                    .font(.headline)

                DatePicker("Datum", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .tint(.blue)

                // Tageswerte
                let total = dailyTotal(on: selectedDate)
                let reached = total >= goal

                HStack {
                    Label(selectedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    Spacer()
                    Text("\(total) ml")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(reached ? .green : .primary)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Material.ultraThin)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                )

                // Zielstatus
                HStack(spacing: 8) {
                    Image(systemName: reached ? "checkmark.seal.fill" : "xmark.seal")
                        .foregroundStyle(reached ? .green : .orange)
                    Text(reached ? String(localized: "goal_reached", defaultValue: "Goal reached") : String(localized: "goal_missed", defaultValue: "Goal missed"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding()
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Material.ultraThin)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 1)
            )

            dailyEntriesSection(for: selectedDate)

            Spacer()
        }
    }

    private func entries(on date: Date) -> [IntakeEntry] {
        let calendar = Calendar.current
        return history
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    @ViewBuilder
    private func dailyEntriesSection(for date: Date) -> some View {
        let dayEntries = entries(on: date)

        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "daily_entries_title", defaultValue: "Entries"))
                .font(.headline)

            if dayEntries.isEmpty {
                Text(String(localized: "daily_entries_empty", defaultValue: "No drinks logged for this day."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dayEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "clock")
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(entry.amount) ml")
                                    .font(.headline.monospacedDigit())
                                Text(entry.date.formatted(date: .omitted, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 10)

                        if index < dayEntries.count - 1 {
                            Divider()
                                .padding(.leading, 36)
                                .overlay(Color.white.opacity(0.2))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Material.ultraThin)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Reminders
    private var remindersView: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressCapsule

            Toggle(isOn: $remindersEnabled) {
                Label(String(localized: "hourly_reminders", defaultValue: "Hourly reminders"), systemImage: "bell")
            }
            .onChange(of: remindersEnabled) { _, newValue in
                if newValue {
                    Task { @MainActor in
                        let granted = await NotificationManager.requestAuthorization()
                        if granted {
                            await NotificationManager.scheduleRepeatingReminder(
                                intervalMinutes: reminderIntervalMinutes,
                                currentIntake: intake,
                                goal: goal
                            )
                        } else {
                            remindersEnabled = false
                        }
                    }
                } else {
                    NotificationManager.cancelAll()
                }
            }
            .toggleStyle(.switch)
            .padding()
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Material.ultraThin)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1))

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "interval_title", defaultValue: "Interval"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker("Interval", selection: $reminderIntervalMinutes) {
                    Text(String(localized: "every_30_min", defaultValue: "Every 30 min")).tag(30)
                    Text(String(localized: "every_60_min", defaultValue: "Every 60 min")).tag(60)
                    Text(String(localized: "every_90_min", defaultValue: "Every 90 min")).tag(90)
                    Text(String(localized: "every_120_min", defaultValue: "Every 120 min")).tag(120)
                }
                .pickerStyle(.segmented)
                .onChange(of: reminderIntervalMinutes) { _, _ in
                    if remindersEnabled {
                        Task {
                            await NotificationManager.scheduleRepeatingReminder(
                                intervalMinutes: reminderIntervalMinutes,
                                currentIntake: intake,
                                goal: goal
                            )
                        }
                    }
                }
            }
            .padding()
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Material.ultraThin)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.35), lineWidth: 1))

            Text(String(localized: "reminders_footer", defaultValue: "When enabled, Siply will send repeating reminders to drink water at the selected interval."))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        HStack(spacing: 28) {
            tabButton(.home, system: "house", label: LocalizedStringKey("tab_home"))
            tabButton(.calendar, system: "calendar", label: LocalizedStringKey("tab_calendar"))
            tabButton(.reminders, system: "bell", label: LocalizedStringKey("tab_reminders"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .frame(maxWidth: 320)
        .background(
            Group {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                } else {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Material.ultraThin)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .font(.title3)
        .foregroundStyle(.primary)
    }

    private func tabButton(_ tab: Tab, system: String, label: LocalizedStringKey) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Image(systemName: system)
                .foregroundStyle(selectedTab == tab ? .blue : .primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(selectedTab == tab ? Color.white.opacity(0.25) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Settings Sheet
    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section(String(localized: "daily_goal", defaultValue: "Daily Goal")) {
                    Stepper(value: $goal, in: 500...6000, step: 50) {
                        HStack {
                            Text(String(localized: "daily_goal", defaultValue: "Daily Goal"))
                            Spacer()
                            Text("\(goal) ml")
                        }
                    }
                }
                Section(String(localized: "quick_add_step", defaultValue: "Quick Add Step")) {
                    Stepper(value: $step, in: 50...500, step: 50) {
                        HStack {
                            Text(String(localized: "quick_add_step", defaultValue: "Quick Add Step"))
                            Spacer()
                            Text("\(step) ml")
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        withAnimation(.spring) { intake = 0 }
                        history.removeAll()
                    } label: {
                        Label(String(localized: "reset_today", defaultValue: "Reset today"), systemImage: "trash")
                    }
                }
            }
            .navigationTitle(String(localized: "settings_title", defaultValue: "Settings"))
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(String(localized: "done_button", defaultValue: "Done")) { showSettings = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Logic
    private func addWater(amount: Int? = nil) {
        let add = amount ?? step
        guard add > 0 else { return }

        let newValue = intake + add

        withAnimation(.spring) {
            intake = newValue
            history.append(IntakeEntry(date: Date(), amount: add))
            if !didReachGoal && newValue >= goal {
                didReachGoal = true
                showCelebration = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.4)) { showCelebration = false }
                }
            }
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private func removeWater(amount: Int) {
        let target = min(max(amount, 0), intake)
        guard target > 0 else { return }

        var remaining = target
        var updatedHistory = history

        for index in stride(from: updatedHistory.count - 1, through: 0, by: -1) {
            if remaining == 0 { break }
            let entry = updatedHistory[index]

            if entry.amount <= remaining {
                remaining -= entry.amount
                updatedHistory.remove(at: index)
            } else {
                let remainder = entry.amount - remaining
                remaining = 0
                if remainder > 0 {
                    updatedHistory[index] = IntakeEntry(date: entry.date, amount: remainder)
                } else {
                    updatedHistory.remove(at: index)
                }
            }
        }

        let removedTotal = target - remaining
        let newValue = max(0, intake - removedTotal)

        guard removedTotal > 0 else { return }

        withAnimation(.spring) {
            intake = newValue
            history = updatedHistory
            if newValue < goal {
                didReachGoal = false
                showCelebration = false
            }
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}

private struct CelebrationView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Expanding ring
            Circle()
                .stroke(Color.green.opacity(0.6), lineWidth: 6)
                .scaleEffect(animate ? 1.2 : 0.8)
                .opacity(animate ? 0.0 : 1.0)
                .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: animate)

            // Inner glow ring
            Circle()
                .stroke(Color.green.opacity(0.35), lineWidth: 12)
                .scaleEffect(animate ? 1.05 : 0.95)
                .blur(radius: 2)
                .opacity(0.7)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)

            // Checkmark
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.green)
                .shadow(color: .white.opacity(0.5), radius: 6, x: 0, y: 0)
        }
        .onAppear { animate = true }
    }
}



private struct DebugMenuView: View {
    var resetAction: () -> Void
    var cancelAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(String(localized: "debug_title", defaultValue: "Debug Menu"))
                    .font(.title2).bold()
                    .padding(.top)

                Text(String(localized: "debug_info", defaultValue: "You can reset the app to see onboarding again."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                // Test Notifications Section
                VStack(spacing: 12) {
                    Text("Test Notifications")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        Task {
                            await sendTestNotification()
                        }
                    }) {
                        Label("Send Test Notification Now", systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button(action: {
                        Task {
                            await sendTestNotificationDelayed()
                        }
                    }) {
                        Label("Send Test Notification (5 sec)", systemImage: "clock.badge")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.1))
                )

                Divider()

                Button(role: .destructive, action: resetAction) {
                    Label(String(localized: "debug_reset", defaultValue: "Reset app (show onboarding)"), systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button(action: cancelAction) {
                    Text(String(localized: "debug_cancel", defaultValue: "Cancel"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
            .navigationTitle(String(localized: "debug_title", defaultValue: "Debug Menu"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func sendTestNotification() async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        guard granted == true else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_title", defaultValue: "Stay Hydrated!")
        content.body = MotivationalMessages.random()
        content.sound = .default
        content.categoryIdentifier = "WATER_REMINDER"
        content.badge = 75

        // Immediate trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test.notification", content: content, trigger: trigger)

        try? await center.add(request)
    }

    private func sendTestNotificationDelayed() async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])

        guard granted == true else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification_title", defaultValue: "Stay Hydrated!")
        content.body = MotivationalMessages.random()
        content.sound = .default
        content.categoryIdentifier = "WATER_REMINDER"
        content.userInfo = [
            "currentIntake": 1500,
            "goal": 2000,
            "progress": 75
        ]
        content.badge = 75

        // 5 second delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test.notification.delayed", content: content, trigger: trigger)

        try? await center.add(request)
    }
}

#Preview {
    ContentView()
}
