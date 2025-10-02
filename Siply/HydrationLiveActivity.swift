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

// MARK: - Live Activity Manager
@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<HydrationActivityAttributes>?

    private init() {}

    func startActivity(userName: String, currentIntake: Int, goal: Int) async {
        // End existing activity first
        await endActivity()

        let attributes = HydrationActivityAttributes(userName: userName)
        let initialState = HydrationActivityAttributes.ContentState(
            currentIntake: currentIntake,
            goal: goal,
            lastUpdated: Date()
        )

        do {
            let activity = try Activity<HydrationActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    func updateActivity(currentIntake: Int, goal: Int) async {
        guard let activity = currentActivity else { return }

        let updatedState = HydrationActivityAttributes.ContentState(
            currentIntake: currentIntake,
            goal: goal,
            lastUpdated: Date()
        )

        await activity.update(.init(state: updatedState, staleDate: nil))
    }

    func endActivity() async {
        guard let activity = currentActivity else { return }
        let finalState = HydrationActivityAttributes.ContentState(
            currentIntake: 0,
            goal: 2000,
            lastUpdated: Date()
        )
        await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        currentActivity = nil
    }
}

// MARK: - Live Activity Views
@available(iOS 16.1, *)
struct HydrationLiveActivityView: View {
    let context: ActivityViewContext<HydrationActivityAttributes>

    var progress: Double {
        let goal = Double(context.state.goal)
        guard goal > 0 else { return 0 }
        return min(1.0, Double(context.state.currentIntake) / goal)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Water drop icon with progress
            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(0.3), lineWidth: 3)
                    .frame(width: 40, height: 40)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan, Color.blue],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(context.state.currentIntake) / \(context.state.goal) ml")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("\(Int(progress * 100))% • \(context.attributes.userName)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color.cyan.opacity(0.1))
    }
}

// Note: Dynamic Island requires Widget Extension to work properly
// For now, we use the standard Live Activity view
// To enable Dynamic Island:
// 1. Create a Widget Extension target
// 2. Move this file to the Widget target
// 3. Implement DynamicIsland view in Widget Extension

// MARK: - App Intent for Quick Actions
@available(iOS 16.0, *)
struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Water"
    static var description: IntentDescription? = IntentDescription("Add water to your daily intake")

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount)ml of water")
    }

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
        // This would trigger your app's water logging logic
        // For now, just return success
        return .result()
    }
}
