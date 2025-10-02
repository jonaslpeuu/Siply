import Foundation

struct MotivationalMessages {
    static let messages: [String] = [
        // Freundlich & Motivierend
        String(localized: "notification_msg_1", defaultValue: "Time for a sip! Your body will thank you 💧"),
        String(localized: "notification_msg_2", defaultValue: "Hydration check! Let's keep that streak going 🌊"),
        String(localized: "notification_msg_3", defaultValue: "Water break! You're doing amazing 💙"),
        String(localized: "notification_msg_4", defaultValue: "Your cells are calling... they need water! 📞💧"),
        String(localized: "notification_msg_5", defaultValue: "Sip sip hooray! Time to hydrate ✨"),

        // Duolingo-Style (freundlich aber persistent)
        String(localized: "notification_msg_6", defaultValue: "Don't let your water gauge cry! Take a sip 🥺"),
        String(localized: "notification_msg_7", defaultValue: "I see you scrolling... but did you drink water? 👀"),
        String(localized: "notification_msg_8", defaultValue: "Your water is getting lonely without you 💔"),
        String(localized: "notification_msg_9", defaultValue: "Quick reminder: You're 60% water. Top it up! 💧"),
        String(localized: "notification_msg_10", defaultValue: "Plot twist: Drinking water makes you feel better! 🎬"),

        // Lustig & Witzig
        String(localized: "notification_msg_11", defaultValue: "Water you waiting for? Time to drink! 😄"),
        String(localized: "notification_msg_12", defaultValue: "Glug glug! Your daily hydration reminder 🐟"),
        String(localized: "notification_msg_13", defaultValue: "H2-Oh yeah! Let's get hydrated 💪"),
        String(localized: "notification_msg_14", defaultValue: "Dehydration is so last hour. Drink up! ⏰"),
        String(localized: "notification_msg_15", defaultValue: "Your future self called. They want you to drink water now 📞"),

        // Gesundheitsbezogen
        String(localized: "notification_msg_16", defaultValue: "Stay sharp! Water helps your brain work better 🧠"),
        String(localized: "notification_msg_17", defaultValue: "Glowing skin starts with hydration ✨💧"),
        String(localized: "notification_msg_18", defaultValue: "Boost your energy! A glass of water helps 🚀"),
        String(localized: "notification_msg_19", defaultValue: "Your kidneys are working hard. Help them out! 💙"),
        String(localized: "notification_msg_20", defaultValue: "Water = Better mood. Science says so! 🔬"),

        // Kurz & Knackig
        String(localized: "notification_msg_21", defaultValue: "Drink! 💧"),
        String(localized: "notification_msg_22", defaultValue: "Hydrate now! 🌊"),
        String(localized: "notification_msg_23", defaultValue: "Water time! ⏰"),
        String(localized: "notification_msg_24", defaultValue: "Sip alert! 🚨"),
        String(localized: "notification_msg_25", defaultValue: "Thirst? Fixed! 💧"),

        // Motivational Quotes Style
        String(localized: "notification_msg_26", defaultValue: "Every sip is a step toward your goal! 🎯"),
        String(localized: "notification_msg_27", defaultValue: "You're crushing it! Now crush a glass of water 💪"),
        String(localized: "notification_msg_28", defaultValue: "Small sips lead to big wins! 🏆"),
        String(localized: "notification_msg_29", defaultValue: "Stay hydrated, stay winning! 🌟"),
        String(localized: "notification_msg_30", defaultValue: "You didn't come this far to only come this far. Drink! 🚀"),

        // Niedlich & Verspielt
        String(localized: "notification_msg_31", defaultValue: "Your water bottle is feeling neglected 🥺💧"),
        String(localized: "notification_msg_32", defaultValue: "Beep boop! Water reminder activated 🤖"),
        String(localized: "notification_msg_33", defaultValue: "The water drop says hi! 👋💧"),
        String(localized: "notification_msg_34", defaultValue: "Splish splash, time for water! 🌊"),
        String(localized: "notification_msg_35", defaultValue: "Your hydration buddy is here! 🐋"),

        // Reality Check Style
        String(localized: "notification_msg_36", defaultValue: "Coffee doesn't count. Drink actual water! ☕→💧"),
        String(localized: "notification_msg_37", defaultValue: "Still reading this? Go drink water! 👀"),
        String(localized: "notification_msg_38", defaultValue: "Reminder: You can't pause your hydration 🎮"),
        String(localized: "notification_msg_39", defaultValue: "Your body is 60% water, not 60% excuses 💪"),
        String(localized: "notification_msg_40", defaultValue: "3 seconds to grab water. You got this! ⏱️"),

        // Streak & Progress bezogen
        String(localized: "notification_msg_41", defaultValue: "Don't break your streak! Take a sip 🔥"),
        String(localized: "notification_msg_42", defaultValue: "You're so close to your goal! Keep going 📊"),
        String(localized: "notification_msg_43", defaultValue: "Every drop counts toward your victory! 💧🎉"),
        String(localized: "notification_msg_44", defaultValue: "Level up your hydration game! 🎮⬆️"),
        String(localized: "notification_msg_45", defaultValue: "Another day, another glass. You're unstoppable! 🌟")
    ]

    static func random() -> String {
        return messages.randomElement() ?? messages[0]
    }
}
