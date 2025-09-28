import AlarmKit
import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var viewModel = ViewModel()
    @State private var showingOnboarding = false
    @State private var selectedTab = 0
    
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Create Tab
            CreateReminderView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("New Alarm Note")
                }
                .tag(0)
            
            // List Tab
            RemindersListView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("My Alarm Notes")
                }
                .tag(1)
                .tabBadge(viewModel.alarmsMap.count)
        }
        .environment(viewModel)
        .onAppear {
            viewModel.fetchAlarms()
            // Show onboarding only if user hasn't seen it before
            if !UserDefaults.standard.bool(forKey: hasSeenOnboardingKey) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingOnboarding = true
                }
            }
            
            // TEMPORARY: Reset to free tier on app launch
            viewModel.resetToFreeTier()
        }
        .tint(.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .onTapGesture {
            hideKeyboard()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
    }
}

struct AlarmCell: View {
    @Environment(ViewModel.self) private var viewModel
    @State private var showingDeleteConfirmation = false
    
    var alarm: Alarm
    var label: LocalizedStringResource
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Status icon with subtle background
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: statusIconName)
                        .font(.title2)
                        .foregroundStyle(statusColor)
                }
                
                // Main information
                VStack(alignment: .leading, spacing: 6) {
                    // Label (Title) - Now the most prominent
                    Text(label)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    // Time/Countdown Display - Secondary
                    if let alertingTime = alarm.alertingTime {
                        Text(alertingTime, style: .time)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    } else if let countdown = alarm.countdownDuration?.preAlert {
                        Text(countdown.customFormatted())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Status tag
                    statusTag
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 8) {
                    // Delete button with confirmation
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundStyle(.red)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(.red.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete reminder")
                }
            }
            .padding(16)
            
            // Additional info section (expandable)
            if alarm.isRepeating || alarm.nextFireTime != nil {
                Divider()
                    .padding(.horizontal, 16)
                
                HStack(spacing: 16) {
                    if alarm.isRepeating {
                        HStack(spacing: 6) {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundStyle(.accent)
                            Text("Repeats")
                                .font(.caption)
                                .foregroundStyle(.accent)
                        }
                    }
                    
                    if let nextFireTime = alarm.nextFireTime {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.white)
                            Text("Next: \(nextFireTime, style: .date) at \(nextFireTime, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color.orange
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBaseColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(cardTintColor)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(cardBorderColor, lineWidth: 1.5)
        )
        .confirmationDialog("Delete Reminder", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.unscheduleAlarm(with: alarm.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this reminder?")
        }
        .accessibilityHint("Swipe left for actions or use the buttons on the right.")
    }
    
    var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title2)
            .foregroundStyle(statusColor)
    }
    
    var statusTag: some View {
        Text(tagLabel)
            .font(.caption)
            .fontWeight(.medium)
            .textCase(.uppercase)
            .foregroundStyle(statusTagTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusTagBackgroundColor)
                    .overlay(
                        Capsule()
                            .stroke(statusTagBorderColor, lineWidth: 0.5)
                    )
            )
    }
    
    var statusIconName: String {
        if isCompleted {
            return "checkmark.circle.fill"
        }
        
        switch alarm.state {
        case .scheduled: return "clock"
        case .countdown: return "timer"
        case .paused: return "pause.circle"
        case .alerting: return "bell.fill"
        @unknown default: return "questionmark"
        }
    }
    
    var tagLabel: String {
        if isCompleted {
            return "Completed"
        }
        
        switch alarm.state {
        case .scheduled: return "Scheduled"
        case .countdown: return "Running"
        case .paused: return "Paused"
        case .alerting: return "Alert"
        @unknown default: return "Unknown"
        }
    }
    
    var statusColor: Color {
        if isCompleted {
            return Color.green
        }
        
        switch alarm.state {
        case .scheduled: return Color.purple
        case .countdown: return Color.orange
        case .paused:    return Color.orange
        case .alerting:  return Color.red
        @unknown default: return Color.gray
        }
    }
    
    var isCompleted: Bool {
        // An alarm is considered completed if:
        // 1. It's a one-time alarm (not repeating)
        // 2. It has a scheduled time that has already passed
        // 3. It's currently in scheduled state (meaning it fired and completed)
        
        guard !alarm.isRepeating else { return false }
        
        if let alertingTime = alarm.alertingTime {
            // If the alarm time has passed, it's completed
            return alertingTime < Date()
        }
        
        return false
    }
    
    // Base background color for the card
    var cardBaseColor: Color {
        Color(.systemBackground)
    }
    
    // A subtle tint to overlay on top of the base color
    var cardTintColor: Color {
        if alarm.isRepeating {
            return Color.purple.opacity(0.05)
        } else if isCompleted {
            return Color.green.opacity(0.03)
        } else {
            switch alarm.state {
            case .scheduled: return Color.purple.opacity(0.03)
            case .countdown: return Color.orange.opacity(0.03)
            case .paused:    return Color.orange.opacity(0.03)
            case .alerting:  return Color.red.opacity(0.03)
            @unknown default: return .clear
            }
        }
    }
    
    var cardBorderColor: Color {
        if alarm.isRepeating {
            // Repeating alarms get purple border
            return Color.purple.opacity(0.4)
        } else if isCompleted {
            // Completed alarms get green border
            return Color.green.opacity(0.3)
        } else {
            // One-time alarms get colored border based on state
            return statusColor.opacity(0.3)
        }
    }
    
    var iconBackgroundColor: Color {
        if alarm.isRepeating {
            // Repeating alarms get purple background for icon
            return Color.purple.opacity(0.15)
        } else if isCompleted {
            // Completed alarms get green background for icon
            return Color.green.opacity(0.15)
        } else {
            // One-time alarms get colored background based on state
            return statusColor.opacity(0.15)
        }
    }
    
    var statusTagTextColor: Color {
        if alarm.isRepeating {
            return Color.purple
        } else if isCompleted {
            return Color.green
        } else {
            return statusColor
        }
    }
    
    var statusTagBackgroundColor: Color {
        if alarm.isRepeating {
            return Color.purple.opacity(0.15)
        } else if isCompleted {
            return Color.green.opacity(0.15)
        } else {
            return statusColor.opacity(0.15)
        }
    }
    
    var statusTagBorderColor: Color {
        if alarm.isRepeating {
            return Color.purple.opacity(0.3)
        } else if isCompleted {
            return Color.green.opacity(0.3)
        } else {
            return statusColor.opacity(0.3)
        }
    }
}

struct CreateReminderView: View {
    @Environment(ViewModel.self) private var viewModel
    @State private var showingOnboarding = false
    @State private var showingPaywall = false
    
    @State private var userInput = AlarmForm()
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Main scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with app description
                        headerSection
                        
                        // Main form
                        VStack(spacing: 20) {
                            textfield
                            scheduleSection
                            createButton
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping anywhere in the scroll view
                    hideKeyboard()
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            // Dismiss keyboard when user starts scrolling
                            hideKeyboard()
                        }
                )
            }
            .navigationTitle("Alarmy Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingOnboarding = true }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingSuccess)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "alarm.fill")
                    .font(.title2)
                    .foregroundStyle(.accent)
                Text("Create Your Alarm Note")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                PlanStatusIndicator()
                
                // Premium button or subscription status indicator
                if !viewModel.isSubscribed {
                    Button(action: {
                        showingPaywall = true
                    }) {
                        HStack(spacing: 4) {
                            Text("\(viewModel.currentAlarmUsage)/\(viewModel.freeAlarmLimit)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "crown.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.orange)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Text("Create notes with actual alarm notifications - never miss anything again")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            
            // Daily reset message
            if !viewModel.isSubscribed && viewModel.hasReachedAlarmLimit {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                    Text("Resets in \(viewModel.timeUntilReset)")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                )
            }
        }
        .padding(.horizontal, 4)
    }
    
    var textfield: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.accent)
                Text("Your Note")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            ZStack(alignment: .topLeading) {
                // Background for the text box
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemFill))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                
                // Multiline big text box
                TextEditor(text: $userInput.label)
                    .font(.body)
                    .padding(12)
                    .frame(minHeight: 100)
                    .background(Color.clear)
                
                // Placeholder
                if userInput.label.isEmpty {
                    Text("Write your note that will alarm you (e.g., 'Take medication at 8pm', 'Call dentist tomorrow')")
                        .foregroundStyle(.placeholder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }
    
    var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.accent)
                Text("Schedule Time")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            // Schedule type toggle
            VStack(alignment: .leading, spacing: 12) {
                Text("When should this alarm go off?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                
                Picker("Schedule Type", selection: $userInput.scheduleType) {
                    ForEach(AlarmForm.ScheduleType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                if userInput.scheduleType == .now {
                    // Schedule Now: Time picker + Repeat days on same line
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 16) {
                            // Time picker section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alarm Time")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.medium)
                                
                                DatePicker("", selection: $userInput.selectedDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color(.tertiarySystemFill))
                                    )
                            }
                            
                            // Repeat days section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Repeat Days")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fontWeight(.medium)
                                
                                daysOfTheWeekSection
                            }
                        }
                    }
                } else {
                    // Schedule Later: Date + Time picker (no repeat days)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date & Time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                        
                        DatePicker("", selection: $userInput.selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                    
                    // Show info about one-time scheduling
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.accent)
                            .font(.caption)
                        Text("This will be a one-time alarm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
    
    var daysOfTheWeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display selected days as a compact text
            if userInput.selectedDays.isEmpty {
                Text("No days selected")
                    .font(.subheadline)
                    .foregroundStyle(.placeholder)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.tertiarySystemFill))
                    )
            } else {
                Text(selectedDaysText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            // Compact day selection buttons
            HStack(spacing: 6) {
                ForEach(Locale.autoupdatingCurrent.orderedWeekdays, id: \.self) { weekday in
                    let isSelected = userInput.isSelected(day: weekday)
                    
                    Button {
                        if isSelected {
                            userInput.selectedDays.remove(weekday)
                        } else {
                            userInput.selectedDays.insert(weekday)
                        }
                    } label: {
                        Text(String(weekday.rawValue.prefix(1)))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.accentColor : Color.clear)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.accentColor.opacity(isSelected ? 0 : 0.4), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                }
            }
        }
    }
    
    private var selectedDaysText: String {
        let sortedDays = userInput.selectedDays.sorted { day1, day2 in
            let weekdays = Locale.autoupdatingCurrent.orderedWeekdays
            return weekdays.firstIndex(of: day1)! < weekdays.firstIndex(of: day2)!
        }
        
        if sortedDays.count <= 3 {
            return sortedDays.map { $0.rawValue.localizedUppercase }.joined(separator: ", ")
        } else {
            let firstDay = sortedDays.first!.rawValue.localizedUppercase
            let lastDay = sortedDays.last!.rawValue.localizedUppercase
            return "\(firstDay) - \(lastDay) (\(sortedDays.count) days)"
        }
    }
    
    var createButton: some View {
        Button {
            // Check if user can create more alarms
            if viewModel.hasReachedAlarmLimit {
                showingPaywall = true
                return
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingSuccess = true
            }
            
            viewModel.scheduleAlarm(with: userInput)
            viewModel.fetchAlarms() // refresh list
            
            // Reset form so user can add another immediately
            userInput = AlarmForm()
            
            // Hide success animation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingSuccess = false
            }
        } label: {
            HStack(spacing: 12) {
                if showingSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                Text(buttonText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(showingSuccess ? .green : .accent)
                    .shadow(color: showingSuccess ? .green.opacity(0.3) : .accent.opacity(0.3), radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
        .disabled(!userInput.isValidAlarm)
        .scaleEffect(showingSuccess ? 1.05 : 1.0)
    }
    
    private var buttonText: String {
        if showingSuccess {
            return "Alarm Note Created!"
        } else if viewModel.hasReachedAlarmLimit {
            return "Upgrade to Create More"
        } else {
            return "Create Alarm Note"
        }
    }
}

struct RemindersListView: View {
    @Environment(ViewModel.self) private var viewModel
    @Binding var selectedTab: Int
    @State private var showingDeleteAllConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Plan status at the top
                        HStack {
                            Spacer()
                            PlanStatusIndicator()
                            Spacer()
                        }
                        .padding(.top, 8)
                        
                        if viewModel.hasUpcomingAlerts {
                            LazyVStack(spacing: 16) {
                                ForEach(Array(viewModel.alarmsMap.values), id: \.0.id) { (alarm, label) in
                                    AlarmCell(alarm: alarm, label: label)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        } else {
                            emptyStateView
                        }
                    }
                }
                .onTapGesture {
                    // Dismiss keyboard when tapping anywhere in the scroll view
                    hideKeyboard()
                }
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            // Dismiss keyboard when user starts scrolling
                            hideKeyboard()
                        }
                )
            }
            .navigationTitle("My Alarm Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDeleteAllConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(!viewModel.hasUpcomingAlerts)
                }
            }
            .confirmationDialog("Delete All Alarms", isPresented: $showingDeleteAllConfirmation) {
                Button("Delete All", role: .destructive) {
                    viewModel.unscheduleAllAlarms()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete all alarm notes? This action cannot be undone.")
            }
        }
    }
    
    var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary.opacity(0.6))
                
                VStack(spacing: 12) {
                    Text("No Alarm Notes Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Create your first alarm note - it will actually ring when it's time")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button(action: {
                    selectedTab = 0 // Switch to New Alarm tab
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Your First Alarm Note")
                    }
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.accent)
                    )
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct TimePickerView: View {
    @Binding var hour: Int
    @Binding var min: Int
    @Binding var sec: Int
    
    private let labelOffset = 40.0
    
    var body: some View {
        HStack(spacing: 0) {
            pickerRow(title: "hr", range: 0..<24, selection: $hour)
            pickerRow(title: "min", range: 0..<60, selection: $min)
            pickerRow(title: "sec", range: 0..<60, selection: $sec)
        }
    }
    
    func pickerRow(title: String, range: Range<Int>, selection: Binding<Int>) -> some View {
        Picker("", selection: selection) {
            ForEach(range, id: \.self) {
                Text("\($0)")
            }
        }
        .pickerStyle(.wheel)
        .overlay {
            Text(title)
                .font(.caption)
                .frame(width: labelOffset, alignment: .leading)
                .offset(x: labelOffset)
        }
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    private let hasSeenOnboardingKey = "hasSeenOnboarding"
    
    private let pages = [
        OnboardingPage(
            icon: "alarm.fill",
            title: "Welcome to Alarmy Reminders",
            description: "The only reminder app that actually buzzes like a real alarm - not just silent notifications"
        ),
        OnboardingPage(
            icon: "exclamationmark.triangle",
            title: "The Problem with Other Apps",
            description: "Regular reminder apps only show silent notifications that you can easily miss or ignore"
        ),
        OnboardingPage(
            icon: "note.text.badge.plus",
            title: "Notes with Alarm Feature",
            description: "Write any note and set it to alarm at a specific time - it will actually ring and vibrate"
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            title: "Real Alarms, Not Just Reminders",
            description: "Get persistent alarms that demand your attention until you acknowledge them"
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Bottom section
                VStack(spacing: 24) {
                    // Page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? .accent : .secondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        if currentPage < pages.count - 1 {
                            Button("Skip") {
                                markOnboardingComplete()
                                dismiss()
                            }
                            .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button("Next") {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Get Started") {
                                markOnboardingComplete()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 34)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        markOnboardingComplete()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: hasSeenOnboardingKey)
        print("✅ Onboarding marked as complete")
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundStyle(.accent)
                .symbolEffect(.bounce, value: page.icon)
            
            // Content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

// Helper to apply a tab badge only when count > 0
private extension View {
    @ViewBuilder
    func tabBadge(_ count: Int) -> some View {
        if count > 0 {
            self.badge(count)
        } else {
            self
        }
    }
}

// Helper function to dismiss keyboard
private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

// Extension to add keyboard dismissal to any view
extension View {
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ViewModel.self) private var viewModel
    @State private var selectedPlan: SubscriptionPlan = .monthly
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var showingPurchaseConfirmation = false
    
    enum SubscriptionPlan: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
        
        var productID: String {
            switch self {
            case .monthly: return "com.alarmyreminders.monthly"
            case .yearly: return "com.alarmyreminders.yearly"
            }
        }
        
        var price: String {
            switch self {
            case .monthly: return "$1.99/month"
            case .yearly: return "$14.99/year"
            }
        }
        
        var savings: String? {
            switch self {
            case .monthly: return nil
            case .yearly: return "Save 37%"
            }
        }
        
        var isBestValue: Bool {
            self == .yearly
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "alarm.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.accent)
                        .symbolEffect(.bounce, value: selectedPlan)
                    
                    Text("Unlock Unlimited\nAlarms")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Never miss anything important again")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Features
                VStack(spacing: 20) {
                    FeatureRow(icon: "infinity", title: "Unlimited Alarms", description: "Create as many reminders as you need")
                    FeatureRow(icon: "headphones", title: "Priority Support", description: "Get help when you need it most")
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Pricing Options
                VStack(spacing: 16) {
                    Text("Choose Your Plan")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(SubscriptionPlan.allCases, id: \.self) { plan in
                        PricingOptionView(
                            plan: plan,
                            isSelected: selectedPlan == plan,
                            onTap: { selectedPlan = plan }
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                // Purchase Button
                Button(action: {
                    showingPurchaseConfirmation = true
                }) {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "crown.fill")
                        }
                        Text(isPurchasing ? "Processing..." : "Continue with \(selectedPlan.rawValue)")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isPurchasing ? .gray : .accent)
                    )
                }
                .disabled(isPurchasing)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                
                // Free Trial Text
                Text("Cancel anytime. No commitment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Purchase Error", isPresented: Binding<Bool>(
                get: { purchaseError != nil },
                set: { _ in purchaseError = nil }
            )) {
                Button("OK") {
                    purchaseError = nil
                }
            } message: {
                Text(purchaseError ?? "")
            }
            .confirmationDialog("Confirm Subscription", isPresented: $showingPurchaseConfirmation) {
                Button("Subscribe to \(selectedPlan.rawValue) - \(selectedPlan.price)", role: .destructive) {
                    Task {
                        await handlePurchase()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You're about to subscribe to the \(selectedPlan.rawValue.lowercased()) plan for \(selectedPlan.price).\n\nThis subscription will auto-renew unless cancelled at least 24 hours before the end of the current period.")
            }
        }
    }
    
    private func handlePurchase() async {
        isPurchasing = true
        purchaseError = nil
        
        do {
            // Use StoreKit 2 for real purchase
            print("🔍 Attempting to load product: \(selectedPlan.productID)")
            let result = try await Product.products(for: [selectedPlan.productID])
            print("🔍 Products loaded: \(result.count) products found")
            
            guard let product = result.first else {
                print("❌ Product not found: \(selectedPlan.productID)")
                throw PurchaseError.productNotFound
            }
            print("✅ Product found: \(product.displayName) - \(product.displayPrice)")
            
            let purchaseResult = try await product.purchase()
            
            switch purchaseResult {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Transaction is verified, update subscription status
                    await transaction.finish()
                    viewModel.updateSubscriptionStatus(true)
                    dismiss()
                case .unverified(_, let error):
                    throw PurchaseError.unverifiedTransaction(error)
                }
            case .userCancelled:
                // User cancelled, no error needed
                break
            case .pending:
                // Transaction is pending (e.g., waiting for parental approval)
                purchaseError = "Purchase is pending approval."
            @unknown default:
                throw PurchaseError.unknownResult
            }
            
        } catch {
            if let purchaseErr = error as? PurchaseError {
                self.purchaseError = purchaseErr.localizedDescription
            } else {
                self.purchaseError = "Purchase failed: \(error.localizedDescription)"
            }
        }
        
        isPurchasing = false
    }
    
    enum PurchaseError: LocalizedError {
        case productNotFound
        case unverifiedTransaction(Error)
        case unknownResult
        
        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "Product not found. Please try again."
            case .unverifiedTransaction(let error):
                return "Transaction verification failed: \(error.localizedDescription)"
            case .unknownResult:
                return "Unknown purchase result. Please try again."
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

struct PricingOptionView: View {
    let plan: PaywallView.SubscriptionPlan
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection indicator
                Circle()
                    .fill(isSelected ? .accent : Color(.separator))
                    .overlay(
                        Circle()
                            .stroke(.accent, lineWidth: 2)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(plan.rawValue)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let savings = plan.savings {
                            Text(savings)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(.orange)
                                )
                        }
                        
                        if plan.isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(.green)
                                )
                        }
                        
                        Spacer()
                    }
                    
                    Text(plan.price)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? .accent : Color(.separator), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct PlanStatusIndicator: View {
    @Environment(ViewModel.self) private var viewModel
    
    var body: some View {
        Text(viewModel.isSubscribed ? "PRO" : "FREE")
    }
}

#Preview {
    ContentView()
}
