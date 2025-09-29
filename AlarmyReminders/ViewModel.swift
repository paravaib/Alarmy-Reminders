import AlarmKit
import SwiftUI
import AppIntents
import StoreKit

@Observable class ViewModel {
    typealias AlarmConfiguration = AlarmManager.AlarmConfiguration<ReminderData>
    typealias AlarmsMap = [UUID: (Alarm, LocalizedStringResource)]
    
    @MainActor var alarmsMap = AlarmsMap()
    @ObservationIgnored private let alarmManager = AlarmManager.shared
    
    // Subscription status
    @MainActor var isSubscribed = false
    @MainActor var freeAlarmLimit = 3
    @MainActor var maxAlarmsEverCreated = 0
    @MainActor var lastResetDate = Date()
    
    @MainActor var hasUpcomingAlerts: Bool {
        !alarmsMap.isEmpty
    }
    
    @MainActor var canCreateMoreAlarms: Bool {
        isSubscribed || maxAlarmsEverCreated < freeAlarmLimit
    }
    
    @MainActor var hasReachedAlarmLimit: Bool {
        !isSubscribed && maxAlarmsEverCreated >= freeAlarmLimit
    }
    
    @MainActor var currentAlarmUsage: Int {
        checkAndResetIfNeeded()
        return max(maxAlarmsEverCreated, alarmsMap.count)
    }
    
    @MainActor var timeUntilReset: String {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        
        let remainingSeconds = Int(tomorrow.timeIntervalSince(now))
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    @MainActor init() {
        // Load the maximum alarms ever created from UserDefaults
        maxAlarmsEverCreated = UserDefaults.standard.integer(forKey: "maxAlarmsEverCreated")
        
        // Load the last reset date
        if let savedDate = UserDefaults.standard.object(forKey: "lastResetDate") as? Date {
            lastResetDate = savedDate
        }
        
        // Load subscription status
        isSubscribed = UserDefaults.standard.bool(forKey: "isSubscribed")
        
        // Check if we need to reset (this will be called automatically)
        checkAndResetIfNeeded()
        
        // Verify subscription status on app launch
        Task {
            await verifySubscriptionStatus()
        }
        
        observeAlarms()
    }
    
    func fetchAlarms() {
        do {
            let remoteAlarms = try alarmManager.alarms
            updateAlarmState(with: remoteAlarms)
        } catch {
            // Handle error silently
        }
    }
    
    func scheduleAlarm(with userInput: AlarmForm) {
        let attributes = AlarmAttributes(presentation: alarmPresentation(with: userInput),
                                         metadata: ReminderData(),
                                         tintColor: Color.accentColor)
        
        let id = UUID()
        let alarmConfiguration = AlarmConfiguration(countdownDuration: userInput.countdownDuration,
                                                    schedule: userInput.schedule,
                                                    attributes: attributes,
                                                    stopIntent: StopIntent(alarmID: id.uuidString),
                                                    secondaryIntent: secondaryIntent(alarmID: id, userInput: userInput))
        
        scheduleAlarm(id: id, label: userInput.localizedLabel, alarmConfiguration: alarmConfiguration)
    }
    
    // Schedules an alarm with an alert only.
    func scheduleAlertOnlyExample() {
        let alertContent = AlarmPresentation.Alert(title: "Reminder", stopButton: .stopButton)
        
        let attributes = AlarmAttributes<ReminderData>(presentation: AlarmPresentation(alert: alertContent),
                                                      tintColor: Color.accentColor)
        
        let alarmConfiguration = AlarmConfiguration(schedule: .twoMinsFromNow, attributes: attributes)
        
        scheduleAlarm(id: UUID(), label: "Quick Reminder", alarmConfiguration: alarmConfiguration)
    }
    
    // Schedules an alarm with countdown button.
    func scheduleCountdownAlertExample() {
        let alertContent = AlarmPresentation.Alert(title: "Time's Up!",
                                                   stopButton: .stopButton,
                                                   secondaryButton: .repeatButton,
                                                   secondaryButtonBehavior: .countdown)
        
        let countdownContent = AlarmPresentation.Countdown(title: "Countdown", pauseButton: .pauseButton)
        
        let pausedContent = AlarmPresentation.Paused(title: "Paused", resumeButton: .resumeButton)
        
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alertContent, countdown: countdownContent, paused: pausedContent),
                                         metadata: ReminderData(category: .work),
                                         tintColor: Color.accentColor)
        
        let id = UUID()
        let alarmConfiguration = AlarmConfiguration(countdownDuration: .init(preAlert: 15 * 60, postAlert: 15 * 60),
                                                    attributes: attributes,
                                                    secondaryIntent: RepeatIntent(alarmID: id.uuidString))
        
        scheduleAlarm(id: UUID(), label: "Work Reminder", alarmConfiguration: alarmConfiguration)
    }
    
    // Schedules an alarm with a custom button to launch the app.
    func scheduleCustomButtonAlertExample() {
        let alertContent = AlarmPresentation.Alert(title: "Important Reminder",
                                                   stopButton: .stopButton,
                                                   secondaryButton: .openAppButton,
                                                   secondaryButtonBehavior: .custom)
        
        let attributes = AlarmAttributes<ReminderData>(presentation: AlarmPresentation(alert: alertContent),
                                                      tintColor: Color.accentColor)
        
        let id = UUID()
        let alarmConfiguration = AlarmConfiguration(schedule: .twoMinsFromNow,
                                                    attributes: attributes,
                                                    stopIntent: StopIntent(alarmID: id.uuidString),
                                                    secondaryIntent: OpenAlarmAppIntent(alarmID: id.uuidString))
        
        scheduleAlarm(id: id, label: "Important Reminder", alarmConfiguration: alarmConfiguration)
    }
    
    func scheduleAlarm(id: UUID, label: LocalizedStringResource, alarmConfiguration: AlarmConfiguration) {
        Task {
            do {
                guard await requestAuthorization() else {
                    return
                }
                let alarm = try await alarmManager.schedule(id: id, configuration: alarmConfiguration)
                await MainActor.run {
                    alarmsMap[id] = (alarm, label)
                    // Track maximum alarms ever created
                    maxAlarmsEverCreated = max(maxAlarmsEverCreated, alarmsMap.count)
                    // Store the label persistently so we can retrieve it after app restart
                    // Convert LocalizedStringResource to String for storage
                    let labelString = String(localized: label)
                    storeAlarmLabel(id, label: labelString)
                    // Store the max alarm count persistently
                    UserDefaults.standard.set(maxAlarmsEverCreated, forKey: "maxAlarmsEverCreated")
                }
            } catch {
                // Handle error silently
            }
        }
    }
    
    func unscheduleAlarm(with alarmID: UUID) {
        // Cancel at AlarmKit level first
        do {
            try alarmManager.cancel(id: alarmID)
        } catch {
            return // Don't update local state if AlarmKit cancellation failed
        }
        
        // Only update local state after successful AlarmKit cancellation
        Task { @MainActor in
            alarmsMap[alarmID] = nil
            // Clean up the stored label
            removeStoredAlarmLabel(alarmID)
        }
    }
    
    func unscheduleAllAlarms() {
        // Cancel everything known to AlarmManager, then clear local state.
        do {
            let existing = try alarmManager.alarms
            
            var successCount = 0
            var failureCount = 0
            
            existing.forEach { alarm in
                do {
                    try alarmManager.cancel(id: alarm.id)
                    successCount += 1
                } catch {
                    failureCount += 1
                }
            }
            
            // Only clear local state if we had some successful cancellations
            if successCount > 0 {
                Task { @MainActor in
                    // Clean up all stored labels before clearing the map
                    alarmsMap.keys.forEach { removeStoredAlarmLabel($0) }
                    alarmsMap.removeAll()
                }
            }
        } catch {
            // Handle error silently
        }
    }
    
    private func alarmPresentation(with userInput: AlarmForm) -> AlarmPresentation {
        let secondaryButtonBehavior = userInput.secondaryButtonBehavior
        let secondaryButton: AlarmButton? = switch secondaryButtonBehavior {
            case .countdown: .repeatButton
            case .custom: .openAppButton
            default: nil
        }
        
        let alertContent = AlarmPresentation.Alert(title: userInput.localizedLabel,
                                                   stopButton: .stopButton,
                                                   secondaryButton: secondaryButton,
                                                   secondaryButtonBehavior: secondaryButtonBehavior)

        guard userInput.countdownDuration != nil else {
            // An alarm without a countdown only specifies an alert state.
            return AlarmPresentation(alert: alertContent)
        }
        
        // With countdown enabled, a presentation appears for both a countdown and paused state.
        let countdownContent = AlarmPresentation.Countdown(title: userInput.localizedLabel,
                                                           pauseButton: .pauseButton)
        
        let pausedContent = AlarmPresentation.Paused(title: "Paused",
                                                     resumeButton: .resumeButton)
        
        return AlarmPresentation(alert: alertContent, countdown: countdownContent, paused: pausedContent)
    }
    
    private func secondaryIntent(alarmID: UUID, userInput: AlarmForm) -> (any LiveActivityIntent)? {
        guard let behavior = userInput.secondaryButtonBehavior else { return nil }
        
        switch behavior {
        case .countdown:
            return RepeatIntent(alarmID: alarmID.uuidString)
        case .custom:
            return OpenAlarmAppIntent(alarmID: alarmID.uuidString)
        @unknown default:
            return nil
        }
    }
    
    private func observeAlarms() {
        Task {
            for await incomingAlarms in alarmManager.alarmUpdates {
                updateAlarmState(with: incomingAlarms)
            }
        }
    }
    
    private func updateAlarmState(with remoteAlarms: [Alarm]) {
        Task { @MainActor in
            
            // Update existing alarm states.
            remoteAlarms.forEach { updated in
                // Try to get the label from existing map, or extract from alarm attributes
                let label = alarmsMap[updated.id]?.1 ?? extractTitleFromAlarm(updated)
                alarmsMap[updated.id] = (updated, label)
            }
            
            let knownAlarmIDs = Set(alarmsMap.keys)
            let incomingAlarmIDs = Set(remoteAlarms.map(\.id))
            
            // Clean-up removed alarms.
            let removedAlarmIDs = Set(knownAlarmIDs.subtracting(incomingAlarmIDs))
            removedAlarmIDs.forEach {
                alarmsMap[$0] = nil
            }
        }
    }
    
    private func requestAuthorization() async -> Bool {
        switch alarmManager.authorizationState {
        case .notDetermined:
            do {
                let state = try await alarmManager.requestAuthorization()
                return state == .authorized
            } catch {
                return false
            }
        case .denied: return false
        case .authorized: return true
        @unknown default: return false
        }
    }
    
    private func extractTitleFromAlarm(_ alarm: Alarm) -> LocalizedStringResource {
        // Try to get the stored label from UserDefaults first
        let storedLabel = UserDefaults.standard.string(forKey: "alarm_label_\(alarm.id.uuidString)")
        if let storedLabel = storedLabel {
            return LocalizedStringResource(stringLiteral: storedLabel)
        }
        
        // If no stored label, provide a more user-friendly default
        return LocalizedStringResource("Alarm Reminder")
    }
    
    @MainActor private func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastResetDay = calendar.startOfDay(for: lastResetDate)
        
        // If it's a new day, reset the counter
        if today > lastResetDay {
            maxAlarmsEverCreated = 0
            lastResetDate = today
            UserDefaults.standard.set(maxAlarmsEverCreated, forKey: "maxAlarmsEverCreated")
            UserDefaults.standard.set(lastResetDate, forKey: "lastResetDate")
        }
    }
    
    @MainActor     func updateSubscriptionStatus(_ subscribed: Bool) {
        isSubscribed = subscribed
        UserDefaults.standard.set(subscribed, forKey: "isSubscribed")
    }
    
    @MainActor func resetToFreeTier() {
        // Reset subscription status
        isSubscribed = false
        UserDefaults.standard.set(false, forKey: "isSubscribed")
        
        // Reset alarm counter
        maxAlarmsEverCreated = 0
        UserDefaults.standard.set(0, forKey: "maxAlarmsEverCreated")
        
        // Reset last reset date to today
        lastResetDate = Date()
        UserDefaults.standard.set(Date(), forKey: "lastResetDate")
        
    }
    
    @MainActor func verifySubscriptionStatus() async {
        // This function verifies the current subscription status against StoreKit
        // and resets it if there's a mismatch
        do {
            let productIDs = ["com.alarmyreminders.monthly", "com.alarmyreminders.yearly"]
            _ = try await Product.products(for: productIDs)
            
            var hasActiveSubscription = false
            
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if productIDs.contains(transaction.productID) {
                        if transaction.revocationDate == nil && 
                           (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                            hasActiveSubscription = true
                            break
                        }
                    }
                case .unverified:
                    continue
                }
            }
            
            // Update subscription status to match actual StoreKit state
            if hasActiveSubscription != isSubscribed {
                updateSubscriptionStatus(hasActiveSubscription)
            }
            
        } catch {
            // Handle error silently
        }
    }
    
    @MainActor func restorePurchases() async -> Bool {
        do {
            // Get all subscription products
            let productIDs = ["com.alarmyreminders.monthly", "com.alarmyreminders.yearly"]
            _ = try await Product.products(for: productIDs)
            
            var hasActiveSubscription = false
            
            // Check for active subscriptions
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    // Check if this is one of our subscription products
                    if productIDs.contains(transaction.productID) {
                        // Check if subscription is still active
                        if transaction.revocationDate == nil && 
                           (transaction.expirationDate == nil || transaction.expirationDate! > Date()) {
                            // User has an active subscription
                            hasActiveSubscription = true
                            updateSubscriptionStatus(true)
                            return true
                        }
                    }
                case .unverified:
                    continue
                }
            }
            
            // No active subscriptions found - reset to free tier
            if !hasActiveSubscription {
                updateSubscriptionStatus(false)
            }
            return hasActiveSubscription
            
        } catch {
            // On error, reset to free tier to be safe
            updateSubscriptionStatus(false)
            return false
        }
    }
    
    private func storeAlarmLabel(_ alarmId: UUID, label: String) {
        UserDefaults.standard.set(label, forKey: "alarm_label_\(alarmId.uuidString)")
    }
    
    private func removeStoredAlarmLabel(_ alarmId: UUID) {
        UserDefaults.standard.removeObject(forKey: "alarm_label_\(alarmId.uuidString)")
    }
}

extension AlarmButton {
    static var openAppButton: Self {
        AlarmButton(text: "Open", textColor: .primary, systemImageName: "app.badge")
    }
    
    static var pauseButton: Self {
        AlarmButton(text: "Pause", textColor: .primary, systemImageName: "pause.fill")
    }
    
    static var resumeButton: Self {
        AlarmButton(text: "Start", textColor: .primary, systemImageName: "play.fill")
    }
    
    static var repeatButton: Self {
        AlarmButton(text: "Repeat", textColor: .primary, systemImageName: "repeat.circle")
    }
    
    static var stopButton: Self {
        AlarmButton(text: "Done", textColor: .white, systemImageName: "stop.circle")
    }
}

extension Alarm {
    var alertingTime: Date? {
        guard let schedule else { return nil }
        
        switch schedule {
        case .fixed(let date):
            return date
        case .relative(let relative):
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
            components.hour = relative.time.hour
            components.minute = relative.time.minute
            return Calendar.current.date(from: components)
        @unknown default:
            return nil
        }
    }
    
    var isRepeating: Bool {
        guard let schedule else { return false }
        
        switch schedule {
        case .fixed:
            return false
        case .relative(let relative):
            switch relative.repeats {
            case .never:
                return false
            case .weekly:
                return true
            @unknown default:
                return false
            }
        @unknown default:
            return false
        }
    }
    
    var nextFireTime: Date? {
        guard let schedule else { return nil }
        
        switch schedule {
        case .fixed(let date):
            return date > Date() ? date : nil
        case .relative(let relative):
            let calendar = Calendar.current
            let now = Date()
            
            // Get today's date with the alarm time
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = relative.time.hour
            components.minute = relative.time.minute
            components.second = 0
            
            guard let todayAlarmTime = calendar.date(from: components) else { return nil }
            
            // If it's a one-time alarm
            if case .never = relative.repeats {
                return todayAlarmTime > now ? todayAlarmTime : nil
            }
            
            // If it's a repeating alarm
            if case .weekly(let weekdays) = relative.repeats {
                // Check if today is one of the repeat days
                let todayWeekday = calendar.component(.weekday, from: now)
                let todayLocaleWeekday = Locale.Weekday(calendarWeekday: todayWeekday)
                
                if let todayLocaleWeekday = todayLocaleWeekday, weekdays.contains(todayLocaleWeekday) {
                    // If today is a repeat day and the time hasn't passed, return today's time
                    if todayAlarmTime > now {
                        return todayAlarmTime
                    }
                }
                
                // Find the next occurrence
                for i in 1...7 {
                    guard let nextDate = calendar.date(byAdding: .day, value: i, to: now) else { continue }
                    let nextWeekday = calendar.component(.weekday, from: nextDate)
                    let nextLocaleWeekday = Locale.Weekday(calendarWeekday: nextWeekday)
                    
                    if let nextLocaleWeekday = nextLocaleWeekday, weekdays.contains(nextLocaleWeekday) {
                        var nextComponents = calendar.dateComponents([.year, .month, .day], from: nextDate)
                        nextComponents.hour = relative.time.hour
                        nextComponents.minute = relative.time.minute
                        nextComponents.second = 0
                        
                        if let nextAlarmTime = calendar.date(from: nextComponents) {
                            return nextAlarmTime
                        }
                    }
                }
            }
            
            return nil
        @unknown default:
            return nil
        }
    }
}

extension Alarm.Schedule {
    static var twoMinsFromNow: Self {
        let twoMinsFromNow = Date.now.addingTimeInterval(2 * 60)
        let time = Alarm.Schedule.Relative.Time(hour: Calendar.current.component(.hour, from: twoMinsFromNow),
                                                minute: Calendar.current.component(.minute, from: twoMinsFromNow))
        return .relative(.init(time: time))
    }
}

extension TimeInterval {
    func customFormatted() -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: self) ?? self.formatted()
    }
}

extension Locale {
    var orderedWeekdays: [Locale.Weekday] {
        let days: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        if let firstDayIdx = days.firstIndex(of: firstDayOfWeek), firstDayIdx != 0 {
            return Array(days[firstDayIdx...] + days[0..<firstDayIdx])
        }
        return days
    }
}

extension Locale.Weekday {
    // Maps Calendar.component(.weekday, from:) -> Locale.Weekday
    // Calendar weekday uses 1 = Sunday ... 7 = Saturday (Gregorian)
    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
