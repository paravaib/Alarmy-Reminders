import AlarmKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ViewModel()
    @State private var showingOnboarding = false
    @State private var selectedTab = 0
    
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
        }
        .environment(viewModel)
        .onAppear {
            viewModel.fetchAlarms()
            // Show onboarding if it's the first time
            if viewModel.alarmsMap.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingOnboarding = true
                }
            }
        }
        .tint(.accent)
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
                    // Time/Countdown Display
                    if let alertingTime = alarm.alertingTime {
                        Text(alertingTime, style: .time)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    } else if let countdown = alarm.countdownDuration?.preAlert {
                        Text(countdown.customFormatted())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    
                    // Label
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
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
                                .foregroundStyle(.secondary)
                            Text("Next: \(nextFireTime, style: .date) at \(nextFireTime, style: .time)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color.gray.opacity(0.1)
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
        Color.white
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
    
    @State private var userInput = AlarmForm()
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Clean white background
                Color.white
                    .ignoresSafeArea()
                
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
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Alarmy Reminders")
            .navigationBarTitleDisplayMode(.large)
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
            }
            
            Text("Create notes with actual alarm notifications - never miss anything again")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
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
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
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
                        .foregroundStyle(.secondary)
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
            
            VStack(alignment: .leading, spacing: 16) {
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
                                .fill(Color.gray.opacity(0.1))
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat Days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fontWeight(.medium)
                    
                    daysOfTheWeekSection
                }
            }
        }
    }
    
    var daysOfTheWeekSection: some View {
        HStack(spacing: 8) {
            ForEach(Locale.autoupdatingCurrent.orderedWeekdays, id: \.self) { weekday in
                let isSelected = userInput.isSelected(day: weekday)
                
                Button {
                    if isSelected {
                        userInput.selectedDays.remove(weekday)
                    } else {
                        userInput.selectedDays.insert(weekday)
                    }
                } label: {
                    Text(weekday.rawValue.localizedUppercase)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isSelected ? Color.accentColor : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(Color.secondary.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                        )
                        .foregroundColor(isSelected ? .white : .primary)
                }
            }
        }
    }
    
    var createButton: some View {
        Button {
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
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text(showingSuccess ? "Alarm Note Created!" : "Create Alarm Note")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
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
}

struct RemindersListView: View {
    @Environment(ViewModel.self) private var viewModel
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Clean white background
                Color.white
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
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
            }
            .navigationTitle("My Alarm Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.unscheduleAllAlarms()
                    }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(!viewModel.hasUpcomingAlerts)
                }
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
                    .foregroundColor(.white)
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
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
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

#Preview {
    ContentView()
}
