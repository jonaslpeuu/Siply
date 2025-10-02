import SwiftUI

struct OnboardingView: View {
    @Binding var userName: String
    @Binding var goal: Int
    @Binding var remindersEnabled: Bool
    @Binding var reminderIntervalMinutes: Int

    var onFinish: () -> Void

    @State private var currentPage: Int = 0
    @FocusState private var isNameFieldFocused: Bool

    @Environment(\.colorScheme) private var colorScheme

    private let totalPages = 8

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                WelcomeScreen()
                    .tag(0)

                FeatureScreen(
                    icon: "drop.fill",
                    title: String(localized: "onboarding_feature1_title", defaultValue: "Track Your Hydration"),
                    subtitle: String(localized: "onboarding_feature1_subtitle", defaultValue: "Beautiful water gauge that fills up as you drink throughout the day"),
                    accentColor: Color.cyan
                )
                .tag(1)

                FeatureScreen(
                    icon: "bell.badge.fill",
                    title: String(localized: "onboarding_feature2_title", defaultValue: "Smart Reminders"),
                    subtitle: String(localized: "onboarding_feature2_subtitle", defaultValue: "Get gentle nudges to stay hydrated at the perfect intervals"),
                    accentColor: Color.purple
                )
                .tag(2)

                FeatureScreen(
                    icon: "chart.bar.fill",
                    title: String(localized: "onboarding_feature3_title", defaultValue: "History & Stats"),
                    subtitle: String(localized: "onboarding_feature3_subtitle", defaultValue: "Track your progress and build healthy hydration habits"),
                    accentColor: Color.green
                )
                .tag(3)

                NameInputScreen(userName: $userName, isNameFieldFocused: $isNameFieldFocused)
                    .tag(4)

                GoalSetupScreen(goal: $goal)
                    .tag(5)

                ReminderSetupScreen(
                    remindersEnabled: $remindersEnabled,
                    reminderIntervalMinutes: $reminderIntervalMinutes
                )
                .tag(6)

                ReadyScreen()
                    .tag(7)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    if currentPage > 0 && currentPage < totalPages - 1 {
                        Button(action: { withAnimation { currentPage -= 1 } }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.white.opacity(0.2)))
                        }
                    }

                    Spacer()

                    if currentPage < totalPages - 1 {
                        Button(action: { onFinish() }) {
                            Text(verbatim: String(localized: "onboarding_skip", defaultValue: "Skip"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)

                Spacer()

                if currentPage < totalPages - 1 {
                    PageIndicator(currentPage: currentPage, totalPages: totalPages)
                        .padding(.bottom, 20)

                    Button(action: handleNext) {
                        Text(verbatim: currentPage == totalPages - 2 ? String(localized: "onboarding_finish", defaultValue: "Get Started") : String(localized: "onboarding_next", defaultValue: "Next"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color(red: 0.2, green: 0.42, blue: 0.98))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                } else {
                    Button(action: onFinish) {
                        Text(verbatim: String(localized: "onboarding_start", defaultValue: "Start Using Siply"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.cyan)
                                    .shadow(color: Color.cyan.opacity(0.4), radius: 20, x: 0, y: 10)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: currentPage) { _, newValue in
            if newValue == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isNameFieldFocused = true
                }
            }
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.37, blue: 0.92),
                Color(red: 0.18, green: 0.58, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func handleNext() {
        // Dismiss keyboard before moving to next page
        isNameFieldFocused = false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if currentPage < totalPages - 1 {
                currentPage += 1
            } else {
                onFinish()
            }
        }
    }
}

// MARK: - Welcome Screen
struct WelcomeScreen: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)

                Image(systemName: "drop.fill")
                    .font(.system(size: 100, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            }

            VStack(spacing: 16) {
                Text(verbatim: "Siply")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(verbatim: String(localized: "onboarding_welcome_subtitle", defaultValue: "Your personal hydration companion"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Feature Screen
struct FeatureScreen: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 220, height: 220)
                    .blur(radius: 50)

                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 180, height: 180)

                Image(systemName: icon)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(accentColor)
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            }

            VStack(spacing: 20) {
                Text(verbatim: title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text(verbatim: subtitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Name Input Screen
struct NameInputScreen: View {
    @Binding var userName: String
    var isNameFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(verbatim: String(localized: "onboarding_name_title", defaultValue: "What's your name?"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)

                Text(verbatim: String(localized: "onboarding_name_description", defaultValue: "We'll use this to personalize your experience"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            TextField(String(localized: "onboarding_name_placeholder", defaultValue: "Enter your name"), text: $userName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color(red: 0.2, green: 0.42, blue: 0.98))
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
                .padding(.horizontal, 32)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, 40)
                .focused(isNameFieldFocused)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Goal Setup Screen
struct GoalSetupScreen: View {
    @Binding var goal: Int

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "target")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(verbatim: String(localized: "onboarding_goal_title", defaultValue: "Daily Goal"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(verbatim: String(localized: "onboarding_goal_description", defaultValue: "How much water do you want to drink each day?"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 24) {
                Text("\(goal) ml")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .monospacedDigit()

                HStack(spacing: 24) {
                    Button(action: { adjustGoal(by: -250) }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    }

                    Button(action: { adjustGoal(by: 250) }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                }

                Text(verbatim: String(localized: "onboarding_goal_tip", defaultValue: "Tip: Most people aim for 2,000–2,500 ml per day"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 48)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            )
            .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }

    private func adjustGoal(by delta: Int) {
        let newGoal = goal + delta
        let clamped = min(max(newGoal, 500), 6000)
        let rounded = (clamped / 50) * 50
        goal = max(500, rounded)
    }
}

// MARK: - Reminder Setup Screen
struct ReminderSetupScreen: View {
    @Binding var remindersEnabled: Bool
    @Binding var reminderIntervalMinutes: Int

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 80, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))

                Text(verbatim: String(localized: "onboarding_reminders_title", defaultValue: "Stay on Track"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(verbatim: String(localized: "onboarding_reminders_description", defaultValue: "Get gentle reminders to drink water throughout the day"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 24) {
                Toggle(isOn: $remindersEnabled.animation(.easeInOut)) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white)
                        Text(verbatim: String(localized: "enable_reminders", defaultValue: "Enable Reminders"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.white)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color.cyan))
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.15))
                )

                if remindersEnabled {
                    VStack(spacing: 16) {
                        Text(verbatim: String(localized: "reminder_interval", defaultValue: "Remind me every"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.8))

                        Picker(String(localized: "interval_title", defaultValue: "Interval"), selection: $reminderIntervalMinutes) {
                            Text(verbatim: "30 min").tag(30)
                            Text(verbatim: "60 min").tag(60)
                            Text(verbatim: "90 min").tag(90)
                            Text(verbatim: "120 min").tag(120)
                        }
                        .pickerStyle(.segmented)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 40)

            if remindersEnabled {
                Text(verbatim: String(localized: "onboarding_notification_permission", defaultValue: "We'll ask for notification permission next"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Ready Screen
struct ReadyScreen: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.green, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            }

            VStack(spacing: 20) {
                Text(verbatim: String(localized: "onboarding_ready_title", defaultValue: "You're All Set!"))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)

                Text(verbatim: String(localized: "onboarding_ready_subtitle", defaultValue: "Let's start your hydration journey"))
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Page Indicator
struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.white : Color.white.opacity(0.3))
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
    }
}

#Preview {
    OnboardingView(
        userName: .constant(""),
        goal: .constant(2000),
        remindersEnabled: .constant(false),
        reminderIntervalMinutes: .constant(60),
        onFinish: {}
    )
}
