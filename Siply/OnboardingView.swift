import SwiftUI

struct OnboardingView: View {
    @Binding var userName: String
    @Binding var goal: Int
    @Binding var remindersEnabled: Bool
    @Binding var reminderIntervalMinutes: Int

    var onFinish: () -> Void

    @State private var page: Int = 0
    @FocusState private var isNameFieldFocused: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var totalPages: Int { slides.count + 1 }

    private var progress: CGFloat {
        guard totalPages > 0 else { return 0 }
        return CGFloat(page + 1) / CGFloat(totalPages)
    }

    private var slides: [OnboardingSlide] {
        [
            OnboardingSlide(
                id: 0,
                title: String(localized: "onboarding_slide_hydrate_title", defaultValue: "Hydration made effortless"),
                subtitle: String(localized: "onboarding_slide_hydrate_subtitle", defaultValue: "Siply turns your water intake into a living gauge with smooth waves and friendly feedback."),
                icon: "drop.fill",
                gradient: [
                    Color(red: 0.35, green: 0.66, blue: 1.0),
                    Color(red: 0.22, green: 0.42, blue: 0.99)
                ],
                accent: Color.white,
                highlights: [
                    .init(icon: "sparkles", text: String(localized: "onboarding_slide_hydrate_point1", defaultValue: "Live water gauge keeps progress vivid")),
                    .init(icon: "bolt.heart", text: String(localized: "onboarding_slide_hydrate_point2", defaultValue: "Quick-add buttons for your go-to glass sizes"))
                ]
            ),
            OnboardingSlide(
                id: 1,
                title: String(localized: "onboarding_slide_reminders_title", defaultValue: "Smart reminders, perfectly timed"),
                subtitle: String(localized: "onboarding_slide_reminders_subtitle", defaultValue: "Set gentle nudges that match your flow and keep streaks alive with insights."),
                icon: "bell.badge.waves.left.and.right.fill",
                gradient: [
                    Color(red: 0.66, green: 0.52, blue: 1.0),
                    Color(red: 0.45, green: 0.41, blue: 1.0)
                ],
                accent: Color.white,
                highlights: [
                    .init(icon: "clock.badge.checkmark", text: String(localized: "onboarding_slide_reminders_point1", defaultValue: "Choose the cadence that fits your day")),
                    .init(icon: "chart.bar.xaxis", text: String(localized: "onboarding_slide_reminders_point2", defaultValue: "History and stats keep you motivated"))
                ]
            )
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            let safeInsets = proxy.safeAreaInsets
            let safeHeight = max(proxy.size.height - safeInsets.top - safeInsets.bottom, 640)
            let cardHeight = min(max(safeHeight * 0.58, 420), 540)

            ZStack {
                onboardingBackground
                    .ignoresSafeArea()

                VStack(spacing: 22) {
                    topBar
                    progressIndicator

                    Spacer(minLength: 4)

                    TabView(selection: $page) {
                        ForEach(slides) { slide in
                            slideCard(for: slide)
                                .frame(maxWidth: .infinity)
                                .tag(slide.id)
                                .padding(.horizontal, 2)
                        }

                        personalizeCard
                            .frame(maxWidth: .infinity)
                            .tag(slides.count)
                            .padding(.horizontal, 2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: cardHeight, alignment: .center)

                    Spacer(minLength: 12)

                    controls
                }
                .padding(.horizontal, 24)
                .padding(.top, safeInsets.top + 28)
                .padding(.bottom, max(safeInsets.bottom + 12, 44))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: page)
        .onChange(of: page) { _, newValue in
            if newValue == slides.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isNameFieldFocused = true
                }
            }
        }
    }

    private var onboardingBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.37, blue: 0.92),
                    Color(red: 0.18, green: 0.58, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.28))
                .blur(radius: 90)
                .frame(width: 320, height: 320)
                .offset(x: -140, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.25))
                .blur(radius: 120)
                .frame(width: 360, height: 360)
                .offset(x: 180, y: 340)
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: "drop.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.white)
                        .font(.system(size: 22, weight: .bold))
                }
                Text("Siply")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.95))
            }

            Spacer()

            if page < totalPages - 1 {
                Button(action: { onFinish() }) {
                    Text(verbatim: String(localized: "onboarding_skip", defaultValue: "Skip"))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                        )
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressIndicator: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), Color.white.opacity(0.65)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(40, width * progress))
            }
        }
        .frame(height: 8)
        .padding(.top, 4)
    }

    private func slideCard(for slide: OnboardingSlide) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: slide.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(height: 190)
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 16)

                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .offset(x: 90, y: -70)

                Image(systemName: slide.icon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(slide.accent)
                    .font(.system(size: 68, weight: .bold))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 8)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: slide.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.white)
                Text(verbatim: slide.subtitle)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                ForEach(slide.highlights) { highlight in
                    highlightPill(highlight, accent: slide.accent)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: 32, reduceTransparency: reduceTransparency, colorScheme: colorScheme)
    }

    private var personalizeCard: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(verbatim: String(localized: "onboarding_personalize_title", defaultValue: "Make Siply yours"))
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.white)

            Text(verbatim: String(localized: "onboarding_personalize_subtitle", defaultValue: "Add your name, daily goal, and reminder plan to start strong."))
                .font(.body)
                .foregroundStyle(Color.white.opacity(0.85))

            inputSection

            goalSection

            reminderSection

            Text(verbatim: String(localized: "onboarding_goal_help", defaultValue: "Tip: most people aim for 2,000–2,500 ml per day."))
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: String(localized: "onboarding_permissions_note", defaultValue: "We’ll ask for notification permission if you enable reminders."))
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.65))
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground(cornerRadius: 32, reduceTransparency: reduceTransparency, colorScheme: colorScheme)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: String(localized: "onboarding_name_label", defaultValue: "Your name"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.8))

            TextField(String(localized: "onboarding_name_placeholder", defaultValue: "Enter your name"), text: $userName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                )
                .foregroundStyle(Color.white)
                .focused($isNameFieldFocused)
        }
    }

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: String(localized: "daily_goal", defaultValue: "Daily Goal"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.8))

            HStack(spacing: 18) {
                RoundedControlButton(systemName: "minus", action: { adjustGoal(by: -100) })

                VStack(spacing: 4) {
                    Text("\(goal) ml")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                    Text(verbatim: String(localized: "onboarding_goal_caption", defaultValue: "Fine-tune in 100 ml steps"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity)

                RoundedControlButton(systemName: "plus", action: { adjustGoal(by: 100) })
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $remindersEnabled.animation(.easeInOut(duration: 0.25))) {
                Label {
                    Text(verbatim: String(localized: "hourly_reminders", defaultValue: "Hourly reminders"))
                        .foregroundStyle(Color.white)
                } icon: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(Color.white)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.white))
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )

            if remindersEnabled {
                Picker(String(localized: "interval_title", defaultValue: "Interval"), selection: $reminderIntervalMinutes) {
                    Text(verbatim: String(localized: "onboarding_interval_30", defaultValue: "30 min"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .tag(30)
                    Text(verbatim: String(localized: "onboarding_interval_60", defaultValue: "60 min"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .tag(60)
                    Text(verbatim: String(localized: "onboarding_interval_90", defaultValue: "90 min"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .tag(90)
                    Text(verbatim: String(localized: "onboarding_interval_120", defaultValue: "120 min"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .tag(120)
                }
                .pickerStyle(.segmented)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            if page > 0 {
                Button(action: { withAnimation { page -= 1 } }) {
                    controlLabel(text: String(localized: "onboarding_back", defaultValue: "Back"), isPrimary: false)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { onFinish() }) {
                    controlLabel(text: String(localized: "onboarding_skip", defaultValue: "Skip"), isPrimary: false)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button(action: handlePrimaryAction) {
                controlLabel(text: page == totalPages - 1 ? String(localized: "onboarding_start", defaultValue: "Start") : String(localized: "onboarding_next", defaultValue: "Next"), isPrimary: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func controlLabel(text: String, isPrimary: Bool) -> some View {
        Text(verbatim: text)
            .font(.headline.weight(.semibold))
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .background(
                Capsule(style: .continuous)
                    .fill(isPrimary ? Color.white : Color.white.opacity(0.18))
            )
            .foregroundStyle(isPrimary ? Color(red: 0.2, green: 0.42, blue: 0.98) : Color.white.opacity(0.92))
            .shadow(color: isPrimary ? Color.black.opacity(0.18) : Color.clear, radius: isPrimary ? 12 : 0, x: 0, y: isPrimary ? 8 : 0)
    }

    private func highlightPill(_ highlight: OnboardingSlide.Highlight, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.22))
                    .frame(width: 36, height: 36)
                Image(systemName: highlight.icon)
                    .foregroundStyle(accent)
                    .font(.system(size: 17, weight: .semibold))
            }

            Text(verbatim: highlight.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .layoutPriority(1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }

    private func adjustGoal(by delta: Int) {
        let newGoal = goal + delta
        let clamped = min(max(newGoal, 500), 6000)
        let rounded = (clamped / 50) * 50
        goal = max(500, rounded)
    }

    private func handlePrimaryAction() {
        if page < totalPages - 1 {
            withAnimation { page += 1 }
        } else {
            onFinish()
        }
    }

    private struct RoundedControlButton: View {
        let systemName: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.22))
                    )
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct OnboardingSlide: Identifiable {
    struct Highlight: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }

    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let accent: Color
    let highlights: [Highlight]
}

private extension View {
    func cardBackground(cornerRadius: CGFloat, reduceTransparency: Bool, colorScheme: ColorScheme) -> some View {
        let baseLight = Color.white.opacity(colorScheme == .dark ? 0.15 : 0.5)
        return self
            .background(
                Group {
                    if reduceTransparency {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(baseLight)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .fill(Material.ultraThin)
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.18 : 0.35), lineWidth: 1)
            )
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
