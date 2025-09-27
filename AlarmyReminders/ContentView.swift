import AlarmKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ViewModel()
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background for a more calming feel
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemGroupedBackground).opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                AlarmAddView()
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
                        .fill(statusColor.opacity(0.15))
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
                    Color(.tertiarySystemBackground)
                        .opacity(0.5)
                )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
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
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.15))
                    .overlay(
                        Capsule()
                            .stroke(statusColor.opacity(0.3), lineWidth: 0.5)
                    )
            )
    }
    
    var statusIconName: String {
        switch alarm.state {
        case .scheduled: "clock"
        case .countdown: "timer"
        case .paused: "pause.circle"
        case .alerting: "bell.fill"
        @unknown default: "questionmark"
        }
    }
    
    var tagLabel: String {
        switch alarm.state {
        case .scheduled: "Scheduled"
        case .countdown: "Running"
        case .paused: "Paused"
        case .alerting: "Alert"
        @unknown default: "Unknown"
        }
    }
    
    var statusColor: Color {
        switch alarm.state {
        case .scheduled: .blue
        case .countdown: .green
        case .paused: .orange
        case .alerting: .red
        @unknown default: .gray
        }
    }
}

struct AlarmAddView: View {
    @Environment(ViewModel.self) private var viewModel
    
    @State private var userInput = AlarmForm()
    @State private var showingSuccess = false
    
    var body: some View {
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
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                )
                
                remindersSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .animation(.easeInOut(duration: 0.3), value: showingSuccess)
    }
    
    var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Create Your Reminder")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            Text("Set a gentle reminder to help you stay mindful and focused")
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
                Text("Reminder Name")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            ZStack(alignment: .topLeading) {
                // Background for the text box
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.tertiarySystemBackground))
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
                    Text("What would you like to be reminded about?")
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
                                .fill(Color(.tertiarySystemBackground))
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
                
                Text(showingSuccess ? "Reminder Created!" : "Create Reminder")
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
    
    var remindersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet")
                    .foregroundStyle(.accent)
                Text("Your Reminders")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            
            if viewModel.hasUpcomingAlerts {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.alarmsMap.values), id: \.0.id) { (alarm, label) in
                        AlarmCell(alarm: alarm, label: label)
                    }
                }
            } else {
                emptyStateView
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
    }
    
    var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Reminders Yet")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Text("Create your first reminder to get started on your mindful journey")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
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
            icon: "leaf.fill",
            title: "Welcome to Alarmy Reminders",
            description: "Your gentle companion for mindful living and peaceful reminders"
        ),
        OnboardingPage(
            icon: "clock.badge.checkmark",
            title: "Set Mindful Reminders",
            description: "Create gentle reminders that help you stay present and focused throughout your day"
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "Calm & Peaceful",
            description: "Experience a soothing interface designed to bring tranquility to your daily routine"
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Ready to Begin?",
            description: "Start your journey towards a more mindful and peaceful lifestyle"
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
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemGroupedBackground),
                        Color(.systemGroupedBackground).opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
