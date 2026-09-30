import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), reminder: "No upcoming reminders", transaction: "No recent transactions")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), reminder: "Doctor Appointment - 5:00 PM", transaction: "Spent ₹500")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.katch.widget")
        
        let reminder = userDefaults?.string(forKey: "latest_reminder") ?? "No upcoming reminders"
        let transaction = userDefaults?.string(forKey: "latest_transaction") ?? "No recent transactions"

        let entry = SimpleEntry(date: Date(), reminder: reminder, transaction: transaction)
        
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let reminder: String
    let transaction: String
}

struct KatchWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Katch")
                    .font(.headline)
                    .bold()
                    .foregroundColor(.white)
                
                Spacer()
                
                Link(destination: URL(string: "katch://action/record")!) {
                    Text("+ Note")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Divider().background(Color.gray)
            
            Text("Next Reminder:")
                .font(.caption2)
                .foregroundColor(.gray)
            Text(entry.reminder)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Divider().background(Color.gray)
            
            Text("Latest Transaction:")
                .font(.caption2)
                .foregroundColor(.gray)
            Text(entry.transaction)
                .font(.caption)
                .foregroundColor(.white)
            
        }
        .padding()
        .background(Color(red: 44/255, green: 44/255, blue: 44/255))
    }
}

@main
struct KatchWidget: Widget {
    let kind: String = "KatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                KatchWidgetEntryView(entry: entry)
                    .containerBackground(Color(red: 44/255, green: 44/255, blue: 44/255), for: .widget)
            } else {
                KatchWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Katch Dashboard")
        .description("Quickly capture notes and view reminders.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
