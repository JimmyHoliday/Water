import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var totalWaterIntake: Int = UserDefaults.standard.integer(forKey: "totalWaterIntake")
    @State private var nextReminderDate: Date = UserDefaults.standard.object(forKey: "nextReminderDate") as? Date ?? Date().addingTimeInterval(60 * 60)
    @State private var reminderActive: Bool = true
    @State private var showWaterIntakeAlert: Bool = false
    @State private var waterInput: String = ""
    @State private var showExtraWaterAlert: Bool = false
    @State private var lastUpdateDate: Date = UserDefaults.standard.object(forKey: "lastUpdateDate") as? Date ?? Date()
    @State private var reminderInterval: Double = UserDefaults.standard.double(forKey: "reminderInterval") > 0 ? UserDefaults.standard.double(forKey: "reminderInterval") : 60.0

    @State private var selectedInterval: Int = UserDefaults.standard.integer(forKey: "selectedInterval") > 0 ? UserDefaults.standard.integer(forKey: "selectedInterval") : 60
    
    @State private var showIntervalAlert: Bool = false

    @State private var doNotDisturbStart: Date = {
        if let date = UserDefaults.standard.object(forKey: "doNotDisturbStart") as? Date {
            return date
        } else {
            return Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        }
    }()

    @State private var doNotDisturbEnd: Date = {
        if let date = UserDefaults.standard.object(forKey: "doNotDisturbEnd") as? Date {
            return date
        } else {
            return Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        }
    }()

    let intervalOptions = [15, 30, 45, 60, 75, 90]

    var body: some View {
        VStack {
            VStack {
                Text(NSLocalizedString("WaterReminder v?", comment: "App title"))
                    .font(.largeTitle)
                    .foregroundColor(.blue.opacity(0.6))
                Text(NSLocalizedString("door John Haverkate", comment: "App author"))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 20)

            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.4) : Color.white)
                .shadow(radius: 5)
                .overlay(
                    VStack {
                        Text(NSLocalizedString("Totale waterinname vandaag:", comment: "Total water intake today"))
                            .font(.title2)
                        Text("\(totalWaterIntake) ml")
                            .font(.largeTitle)
                            .foregroundColor(.blue)

                        HStack {
                            Button(action: {
                                showExtraWaterAlert = true
                            }) {
                                Text(NSLocalizedString("Voeg waterinname toe", comment: "Add water intake button"))
                                    .font(.subheadline)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .alert(NSLocalizedString("Waterinname", comment: "Water intake alert title"), isPresented: $showExtraWaterAlert, actions: {
                                TextField(NSLocalizedString("Voer het aantal ml in:", comment: "Enter ml of water"), text: $waterInput)
                                    .keyboardType(.numberPad)
                                Button(NSLocalizedString("Toevoegen", comment: "Add button"), action: {
                                    if let ml = Int(waterInput), ml > 0 {
                                        totalWaterIntake += ml
                                        UserDefaults.standard.set(totalWaterIntake, forKey: "totalWaterIntake")
                                    }
                                    waterInput = ""
                                    checkForNewDay()
                                })
                                Button(NSLocalizedString("Annuleren", comment: "Cancel button"), role: .cancel, action: {})
                            })

                            Button(action: {
                                totalWaterIntake = 0
                                UserDefaults.standard.set(totalWaterIntake, forKey: "totalWaterIntake")
                            }) {
                                Text(NSLocalizedString("Reset", comment: "Reset button"))
                                    .font(.subheadline)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    .padding()
                )
                .padding()

            Spacer()

            Text(String(format: NSLocalizedString("Interval ingesteld op %d minuten", comment: "Interval set message"), selectedInterval))
                .font(.title3)
                .foregroundColor(.blue)

            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color.gray.opacity(0.4) : Color.white)
                .shadow(radius: 5)
                .overlay(
                    VStack {
                        Text(NSLocalizedString("Zet herinnering interval:", comment: "Set reminder interval"))
                            .font(.headline)
                            .padding(.top)

                        Picker(NSLocalizedString("Selecteer interval", comment: "Picker label"), selection: $selectedInterval) {
                            ForEach(intervalOptions, id: \.self) { interval in
                                Text(String(format: NSLocalizedString("%d minuten", comment: "Minutes option"), interval))
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: 200)
                        .onChange(of: selectedInterval) { oldValue, newValue in
                            reminderInterval = Double(newValue)
                            UserDefaults.standard.set(reminderInterval, forKey: "reminderInterval")
                            UserDefaults.standard.set(newValue, forKey: "selectedInterval")
                            setupReminders()
                        }
                        .padding(.bottom)
                    }
                    .padding()
                )
                .padding()

            Spacer()

            Text(NSLocalizedString("Niet-storen tijd instellen:", comment: "Set do-not-disturb time"))
                .font(.headline)

            HStack {
                DatePicker(NSLocalizedString("Start", comment: "Do-not-disturb start"), selection: $doNotDisturbStart, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: doNotDisturbStart) { oldValue, newValue in
                        UserDefaults.standard.set(newValue, forKey: "doNotDisturbStart")
                        setupReminders()
                    }
                DatePicker(NSLocalizedString("Einde", comment: "Do-not-disturb end"), selection: $doNotDisturbEnd, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: doNotDisturbEnd) { oldValue, newValue in
                        UserDefaults.standard.set(newValue, forKey: "doNotDisturbEnd")
                        setupReminders()
                    }
            }

            Spacer()
        }
        .background(Color.blue.opacity(0.1).edgesIgnoringSafeArea(.all))
        .onAppear {
            requestNotificationPermission()
            setupReminders()
            checkForNewDay()
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print(NSLocalizedString("Toestemming voor meldingen verleend.", comment: "Notification permission granted message"))
            }
        }
    }

    func setupReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Water Reminder", comment: "Notification title")
        content.body = NSLocalizedString("Vergeet niet water te drinken!", comment: "Notification body")
        content.sound = UNNotificationSound.default

        var nextReminderDate = Date()

        repeat {
            nextReminderDate.addTimeInterval(reminderInterval * 60)
        } while isDuringDoNotDisturb(nextReminderDate)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: nextReminderDate.timeIntervalSinceNow, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print(error.localizedDescription)
            }
        }

        self.nextReminderDate = nextReminderDate
        UserDefaults.standard.set(nextReminderDate, forKey: "nextReminderDate")
    }

    func checkForNewDay() {
        let calendar = Calendar.current
        if calendar.isDateInToday(lastUpdateDate) == false {
            totalWaterIntake = 0
            UserDefaults.standard.set(totalWaterIntake, forKey: "totalWaterIntake")
            lastUpdateDate = Date()
            UserDefaults.standard.set(lastUpdateDate, forKey: "lastUpdateDate")
        }
    }

    func isDuringDoNotDisturb(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        let doNotDisturbStart = calendar.date(bySettingHour: calendar.component(.hour, from: doNotDisturbStart), minute: calendar.component(.minute, from: doNotDisturbStart), second: 0, of: Date())!
        let doNotDisturbEnd = calendar.date(bySettingHour: calendar.component(.hour, from: doNotDisturbEnd), minute: calendar.component(.minute, from: doNotDisturbEnd), second: 0, of: Date())!

        let doNotDisturbStartComponents = calendar.dateComponents([.hour, .minute], from: doNotDisturbStart)
        let doNotDisturbEndComponents = calendar.dateComponents([.hour, .minute], from: doNotDisturbEnd)

        let startHour = doNotDisturbStartComponents.hour ?? 0
        let startMinute = doNotDisturbStartComponents.minute ?? 0
        let endHour = doNotDisturbEndComponents.hour ?? 0
        let endMinute = doNotDisturbEndComponents.minute ?? 0

        if startHour < endHour || (startHour == endHour && startMinute < endMinute) {
            return (hour > startHour || (hour == startHour && minute >= startMinute)) && (hour < endHour || (hour == endHour && minute < endMinute))
        } else {
            return (hour >= startHour || hour < endHour || (hour == endHour && minute < endMinute))
        }
    }
}
