import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Activity Attributes
struct HydrationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentIntake: Int
        var goal: Int
        var lastUpdated: Date
    }

    var userName: String
}

// MARK: - App Intent for Adding Water
@available(iOS 16.0, *)
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Water"
    static var description: IntentDescription = IntentDescription("Add water to your daily intake")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Amount (ml)")
    var amount: Int

    init(amount: Int) {
        self.amount = amount
    }

    init() {
        self.amount = 250
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Write to App Group UserDefaults
        if let userDefaults = UserDefaults(suiteName: "group.WhitoutCookies.Siply") {
            let timestamp = Date().timeIntervalSince1970
            userDefaults.set(amount, forKey: "pendingWaterAmount")
            userDefaults.set(timestamp, forKey: "pendingWaterTimestamp")
            userDefaults.synchronize()

            print("🔵 Widget: Wrote \(amount)ml to UserDefaults at \(timestamp)")

            // Post notification to trigger update
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("com.siply.waterAdded" as CFString),
                nil,
                nil,
                true
            )
        }
        return .result()
    }
}

// MARK: - Live Activity Widget Configuration
@available(iOS 16.2, *)
struct HydrationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HydrationActivityAttributes.self) { context in
            // Lock Screen view
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(context.state.currentIntake)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                        Text("ml")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(context.state.goal)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("ml")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    let progress = min(1.0, Double(context.state.currentIntake) / Double(max(1, context.state.goal)))

                    VStack(spacing: 12) {
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.cyan, .blue],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * progress, height: 8)
                            }
                        }
                        .frame(height: 8)

                        // Buttons
                        HStack(spacing: 8) {
                            Link(destination: URL(string: "siply://addwater?amount=150")!) {
                                Text("150ml")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.3)))
                            }

                            Link(destination: URL(string: "siply://addwater?amount=250")!) {
                                Text("250ml")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.cyan.opacity(0.6)))
                            }

                            Link(destination: URL(string: "siply://addwater?amount=500")!) {
                                Text("500ml")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(Color.white.opacity(0.3)))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.cyan)
            } compactTrailing: {
                let progress = min(1.0, Double(context.state.currentIntake) / Double(max(1, context.state.goal)))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
            } minimal: {
                Image(systemName: "drop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - Lock Screen View
@available(iOS 16.1, *)
struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<HydrationActivityAttributes>

    var progress: Double {
        let goal = Double(context.state.goal)
        guard goal > 0 else { return 0 }
        return min(1.0, Double(context.state.currentIntake) / goal)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Water drop icon with progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(context.state.currentIntake) / \(context.state.goal) ml")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                    Text("•")
                        .font(.system(size: 13))
                    Text(context.attributes.userName)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Quick add button
            Link(destination: URL(string: "siply://addwater?amount=250")!) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .activityBackgroundTint(Color.cyan.opacity(0.1))
    }
}
