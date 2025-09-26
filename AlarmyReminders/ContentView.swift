import AlarmKit
import SwiftUI

struct ContentView: View {
    @State private var viewModel = ViewModel()
    @State private var showAddSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                content
            }
            .navigationTitle("Alarmy Reminders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    menuButton
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AlarmAddView()
        }
        .environment(viewModel)
        .onAppear {
            viewModel.fetchAlarms()
        }
        .tint(.accent)
    }
    
    var menuButton: some View {
        Menu {
            // Schedules an alarm with an alert but no additional configuration.
            Button {
                viewModel.scheduleAlertOnlyExample()
            } label: {
                Label("Quick Alert", systemImage: "bell.circle.fill")
            }
            
            // Schedules an alarm with a countdown button.
            Button {
                viewModel.scheduleCountdownAlertExample()
            } label: {
                Label("Countdown Timer", systemImage: "timer.circle.fill")
            }
            
            // Schedules an alarm with a custom button to launch the app.
            Button {
                viewModel.scheduleCustomButtonAlertExample()
            } label: {
                Label("Custom Alert", systemImage: "alarm.fill")
            }
            
            Divider()
            
            // Displays a sheet with configuration options for a new alarm.
            Button {
                showAddSheet.toggle()
            } label: {
                Label("Create New Reminder", systemImage: "plus.circle.fill")
            }
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.accent)
        }
    }
    
    @ViewBuilder var content: some View {
        if viewModel.hasUpcomingAlerts {
            alarmList(alarms: Array(viewModel.alarmsMap.values))
        } else {
            VStack(spacing: 24) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 80))
                        .foregroundStyle(.accent.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("No Active Reminders")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create your first reminder to get started")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Button {
                    showAddSheet.toggle()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Reminder")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(.accent)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding()
        }
    }
    
    func alarmList(alarms: [ViewModel.AlarmsMap.Value]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(alarms, id: \.0.id) { (alarm, label) in
                    AlarmCell(alarm: alarm, label: label)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.unscheduleAlarm(with: alarm.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

struct AlarmCell: View {
    var alarm: Alarm
    var label: LocalizedStringResource
    
    var body: some View {
        HStack(spacing: 16) {
            // Time/Countdown Display
            VStack(alignment: .leading, spacing: 4) {
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
                
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status Indicator
            VStack(spacing: 8) {
                statusIcon
                statusTag
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    var statusIcon: some View {
        Image(systemName: statusIconName)
            .font(.title2)
            .foregroundStyle(statusColor)
    }
    
    var statusTag: some View {
        Text(tagLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusColor)
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
    @Environment(\.dismiss) private var dismiss
    @Environment(ViewModel.self) private var viewModel
    
    @State private var userInput = AlarmForm()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        textfield
                        countdownSection
                        scheduleSection
                        secondaryButtonSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Create Reminder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        viewModel.scheduleAlarm(with: userInput)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!userInput.isValidAlarm)
                }
            }
        }
    }
    
    var textfield: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Reminder Label", systemImage: "text.cursor")
                .font(.headline)
                .foregroundStyle(.primary)
            
            TextField("Enter reminder name", text: $userInput.label)
                .textFieldStyle(.roundedBorder)
                .font(.body)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    var countdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Countdown Timer", systemImage: "timer", isOn: $userInput.preAlertEnabled)
                .font(.headline)
                .toggleStyle(SwitchToggleStyle(tint: .accent))
            
            if userInput.preAlertEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Countdown Duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TimePickerView(hour: $userInput.selectedPreAlert.hour, min: $userInput.selectedPreAlert.min, sec: $userInput.selectedPreAlert.sec)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.quaternary))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Schedule Time", systemImage: "calendar", isOn: $userInput.scheduleEnabled)
                .font(.headline)
                .toggleStyle(SwitchToggleStyle(tint: .accent))
            
            if userInput.scheduleEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Alarm Time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    DatePicker("", selection: $userInput.selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.quaternary))
                        )
                    
                    Text("Repeat Days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    daysOfTheWeekSection
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    var daysOfTheWeekSection: some View {
        HStack(spacing: 8) {
            ForEach(Locale.autoupdatingCurrent.orderedWeekdays, id: \.self) { weekday in
                Button(action: {
                    if userInput.isSelected(day: weekday) {
                        userInput.selectedDays.remove(weekday)
                    } else {
                        userInput.selectedDays.insert(weekday)
                    }
                }) {
                    Text(weekday.rawValue.localizedUppercase)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 32, height: 32)
                }
                .foregroundStyle(userInput.isSelected(day: weekday) ? .white : .primary)
                .background(
                    Circle()
                        .fill(userInput.isSelected(day: weekday) ? .accent : Color(.quaternary))
                )
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }
    
    var secondaryButtonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Alert Actions", systemImage: "button.programmable")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Picker("Secondary Button", selection: $userInput.selectedSecondaryButton) {
                ForEach(AlarmForm.SecondaryButtonOption.allCases, id: \.self) { button in
                    Text(button.rawValue).tag(button)
                }
            }
            .pickerStyle(.segmented)
            
            if userInput.selectedSecondaryButton == .countdown {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Repeat Duration")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TimePickerView(hour: $userInput.selectedPostAlert.hour, min: $userInput.selectedPostAlert.min, sec: $userInput.selectedPostAlert.sec)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.quaternary))
                        )
                }
            }
            
            let callout = switch userInput.selectedSecondaryButton {
            case .none: "Only the Stop button will be displayed in the alarm alert."
            case .countdown: "The Repeat option will be available when the alarm is triggered."
            case .openApp: "The Open App button will be displayed when the alarm is triggered."
            }
            
            Text(callout)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
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
            .background(.clear)
        }
        .pickerStyle(.wheel)
        .tint(.white)
        .overlay {
            Text(title)
                .font(.caption)
                .frame(width: labelOffset, alignment: .leading)
                .offset(x: labelOffset)
        }
    }
}

#Preview {
    ContentView()
}
