import ActivityKit
import Foundation

// MARK: - Activity Attributes (must match Widget Extension)
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
            print("✅ Live Activity started successfully")
        } catch {
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
        }
    }

    func updateActivity(currentIntake: Int, goal: Int) async {
        guard let activity = currentActivity else {
            print("⚠️ No active Live Activity to update")
            return
        }

        let updatedState = HydrationActivityAttributes.ContentState(
            currentIntake: currentIntake,
            goal: goal,
            lastUpdated: Date()
        )

        await activity.update(.init(state: updatedState, staleDate: nil))
        print("✅ Live Activity updated: \(currentIntake)/\(goal) ml")
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
        print("✅ Live Activity ended")
    }
}
