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

    // Tutorial state
    @AppStorage("has_seen_tutorial") private var hasSeenTutorial: Bool = false
    @State private var showTutorial: Bool = false
    @State private var tutorialStep: Int = 0

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

            // Tutorial overlay
            if showTutorial {
                tutorialOverlay
            }
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
                    // Start tutorial after onboarding
                    if !hasSeenTutorial {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showTutorial = true
                            tutorialStep = 0
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
                    // Reset onboarding and tutorial flags
                    hasSeenOnboarding = false
                    hasSeenTutorial = false
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
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: String(localized: "hello_name", defaultValue: "Hello %@"), userName.isEmpty ? "Mike" : userName))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)

                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                if suppressSettingsTap {
                    suppressSettingsTap = false
                } else {
                    showSettings = true
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .background {
                        if reduceTransparency {
                            Circle().fill(Color.white.opacity(0.35))
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1.5))
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "progress_title", defaultValue: "Progress"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(Int(round(progress * 100)))%")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        intake = 0
                        history.removeAll()
                        didReachGoal = false
                        showCelebration = false
                    }
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background {
                            if reduceTransparency {
                                Circle().fill(Color.white.opacity(0.25))
                            } else {
                                Circle().fill(.ultraThinMaterial)
                            }
                        }
                        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey(String(localized: "reset_today", defaultValue: "Reset today")))
            }

            ZStack(alignment: .leading) {
                Group {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.2))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 1.5)
                )

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let height = proxy.size.height
                    let fillWidth = max(0, width * progress)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.cyan.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.3), Color.clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .frame(width: fillWidth, height: height)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: progress)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(height: 22)

            HStack {
                Text("\(intake) ml")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                Spacer()
                Text(String(localized: "goal_label", defaultValue: "Goal:") + " \(goal) ml")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.25))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
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
        VStack(spacing: 16) {
            ZStack {
                // Outer ring with gradient
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 280, height: 280)
                    .shadow(color: .white.opacity(0.3), radius: 12, x: 0, y: 4)

                // Inner shadow circle
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 276, height: 276)

                // Water fill with animated wave
                Circle()
                    .fill(Color.clear)
                    .frame(width: 276, height: 276)
                    .overlay(
                        Group {
                            if progress > 0 {
                                WaterWaves(progress: progress)
                            }
                        }
                    )
                    .clipShape(Circle())

                VStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "tap_to_add_water", defaultValue: "Tap to Add Water"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .opacity(progress < 0.1 ? 1 : 0.6)

                if showCelebration {
                    CelebrationView()
                        .frame(width: 280, height: 280)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Circle())
            .onTapGesture { addWater() }
            .accessibilityAddTraits(.isButton)

            HStack(spacing: 8) {
                Circle().fill(Color.blue).frame(width: 8, height: 8)
                Circle().fill(Color.white.opacity(0.4)).frame(width: 8, height: 8)
                Circle().fill(Color.white.opacity(0.4)).frame(width: 8, height: 8)
            }
            .padding(.top, 4)
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
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(text)
                .font(.callout.weight(.bold))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background {
            if reduceTransparency {
                Capsule().fill(Color.white.opacity(0.3))
            } else {
                Capsule().fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .foregroundStyle(reduceTransparency ? Color.primary : Color.white)
        .shadow(color: gradientColors[0].opacity(reduceTransparency ? 0 : 0.4), radius: 12, x: 0, y: 6)
    }

    // MARK: - Stats

    private func dailyTotal(on date: Date) -> Int {
        return entries(on: date).reduce(0) { $0 + $1.amount }
    }

    private var calendarView: some View {
        VStack(spacing: 16) {
            progressCapsule

            // Kalender & Tagesübersicht
            VStack(alignment: .leading, spacing: 16) {
                Text(String(localized: "calendar_title", defaultValue: "Calendar"))
                    .font(.title3.weight(.bold))

                DatePicker("Datum", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .tint(.blue)
                    .padding(.vertical, 8)

                // Tageswerte
                let total = dailyTotal(on: selectedDate)
                let reached = total >= goal

                HStack {
                    Label(selectedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.callout.weight(.medium))
                    Spacer()
                    Text("\(total) ml")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(reached ? .green : .primary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)

                // Zielstatus
                HStack(spacing: 10) {
                    Image(systemName: reached ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(reached ? .green : .orange)
                    Text(reached ? String(localized: "goal_reached", defaultValue: "Goal reached") : String(localized: "goal_missed", defaultValue: "Goal missed"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(reached ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                )
            }
            .padding(18)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

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

        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "daily_entries_title", defaultValue: "Entries"))
                .font(.title3.weight(.bold))

            if dayEntries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "drop.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text(String(localized: "daily_entries_empty", defaultValue: "No drinks logged for this day."))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dayEntries.enumerated()), id: \.element.id) { index, entry in
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "drop.fill")
                                    .font(.body)
                                    .foregroundStyle(.blue)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(entry.amount) ml")
                                    .font(.headline.weight(.semibold).monospacedDigit())
                                Text(entry.date.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 12)

                        if index < dayEntries.count - 1 {
                            Divider()
                                .padding(.leading, 58)
                                .overlay(Color.primary.opacity(0.1))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.25))
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.5), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)
    }

    // MARK: - Reminders
    private var remindersView: some View {
        VStack(alignment: .leading, spacing: 16) {
            progressCapsule

            Toggle(isOn: $remindersEnabled) {
                Label(String(localized: "hourly_reminders", defaultValue: "Hourly reminders"), systemImage: "bell.fill")
                    .font(.callout.weight(.semibold))
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
            .tint(.blue)
            .padding(16)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.5), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "interval_title", defaultValue: "Interval"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
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
            .padding(16)
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.5), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 6)

            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text(String(localized: "reminders_footer", defaultValue: "When enabled, Siply will send repeating reminders to drink water at the selected interval."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.1))
            )

            Spacer()
        }
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        HStack(spacing: 32) {
            tabButton(.home, system: "house.fill", label: LocalizedStringKey("tab_home"))
            tabButton(.calendar, system: "calendar", label: LocalizedStringKey("tab_calendar"))
            tabButton(.reminders, system: "bell.fill", label: LocalizedStringKey("tab_reminders"))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 28)
        .frame(maxWidth: 340)
        .background(
            Group {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color.white.opacity(0.3))
                } else {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 16, x: 0, y: 8)
        .frame(maxWidth: .infinity)
        .font(.title3)
        .foregroundStyle(.primary)
    }

    private func tabButton(_ tab: Tab, system: String, label: LocalizedStringKey) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: system)
                    .font(.system(size: 22, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Color.blue : Color.primary.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(selectedTab == tab ? Color.blue.opacity(0.15) : Color.clear)
                            .scaleEffect(selectedTab == tab ? 1 : 0.8)
                    )
            }
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

    // MARK: - Tutorial Overlay
    @ViewBuilder
    private var tutorialOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(tutorialStep == 0 ? 0.7 : 0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent tap through
                }

            // Highlight the water gauge on step 0
            if tutorialStep == 0 {
                GeometryReader { geometry in
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 300, height: 300)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2.5)
                        .shadow(color: .white.opacity(0.8), radius: 30)
                        .allowsHitTesting(false)
                }
            }

            VStack {
                Spacer()

                VStack(spacing: 20) {
                    if tutorialStep == 0 {
                        VStack(spacing: 16) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)

                            Text(String(localized: "tutorial_step1_title", defaultValue: "Tap to Add Water"))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Text(String(localized: "tutorial_step1_description", defaultValue: "Tap the water circle to track your water intake. You can also use the quick add buttons below."))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else if tutorialStep == 1 {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)

                            Text(String(localized: "tutorial_step2_title", defaultValue: "Track Your History"))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Text(String(localized: "tutorial_step2_description", defaultValue: "View your daily progress and track your hydration history in the calendar tab."))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else if tutorialStep == 2 {
                        VStack(spacing: 16) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)

                            Text(String(localized: "tutorial_step3_title", defaultValue: "Set Reminders"))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)

                            Text(String(localized: "tutorial_step3_description", defaultValue: "Never forget to drink water! Enable reminders in the bell tab to stay hydrated."))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }

                    Button(action: {
                        if tutorialStep < 2 {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                tutorialStep += 1
                                // Switch to respective tab
                                if tutorialStep == 1 {
                                    selectedTab = .calendar
                                } else if tutorialStep == 2 {
                                    selectedTab = .reminders
                                }
                            }
                        } else {
                            // Finish tutorial
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showTutorial = false
                                hasSeenTutorial = true
                                selectedTab = .home
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Text(tutorialStep < 2 ? String(localized: "tutorial_next", defaultValue: "Next") : String(localized: "tutorial_finish", defaultValue: "Got it!"))
                                .font(.headline.weight(.bold))
                            if tutorialStep < 2 {
                                Image(systemName: "arrow.right")
                                    .font(.headline.weight(.bold))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                            }
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                        )
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 150)
            }
        }
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
