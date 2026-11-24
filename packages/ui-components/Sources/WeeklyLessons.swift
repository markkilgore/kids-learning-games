import LearningPersistence
import Narration
import SwiftUI

struct LessonWeek: Decodable, Identifiable {
    let start: String
    let end: String
    let dates: String
    let overview: String
    let activities: [LessonActivity]
    var id: String { start }

    func homeTitle(on day: String) -> String {
        day <= end ? "This Week" : "Latest Week"
    }

    static func available(in weeks: [LessonWeek], on day: String) -> [LessonWeek] {
        weeks.filter { $0.start <= day }.sorted { $0.start > $1.start }
    }

    static func dayKey(_ date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}

struct LessonActivity: Decodable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let steps: [LessonStep]
}

struct LessonStep: Decodable {
    let spoken: String?
    let prompt: String
    let scene: String
    let choices: [String]
    let answer: String
    let hint: String
    let moves: Int?
    let track: Bool?
}

public struct WeeklyLessonsButton: View {
    private let weeks: [LessonWeek]
    private let guide: String
    private let color: Color
    private let progress: NamespacedProgressStore<Set<String>>
    @State private var showing = false

    public init(resource: String, namespace: String, guide: String, color: Color) {
        self.guide = guide
        self.color = color
        progress = try! NamespacedProgressStore(namespace: namespace, fileName: "weekly-lessons.json")
        weeks = Self.load(resource)
    }

    private static var catalogs: [String: [LessonWeek]] = [:]
    private static func load(_ resource: String) -> [LessonWeek] {
        if let cached = catalogs[resource] { return cached }
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let weeks = try? JSONDecoder().decode([LessonWeek].self, from: data) else { return [] }
        catalogs[resource] = weeks
        return weeks
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let today = LessonWeek.dayKey(context.date)
            let available = LessonWeek.available(in: weeks, on: today)
            if let latest = available.first {
                let title = latest.homeTitle(on: today)
                Button { showing = true } label: {
                    VStack {
                        Label(title, systemImage: "calendar").font(.headline)
                        Text(latest.dates).font(.caption)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
                .accessibilityIdentifier("weekly-home")
                .sheet(isPresented: $showing) {
                    WeeklyShelf(weeks: available, guide: guide, color: color, progress: progress)
                }
            }
        }
    }
}

private struct WeeklyShelf: View {
    let weeks: [LessonWeek]
    let guide: String
    let color: Color
    let progress: NamespacedProgressStore<Set<String>>
    @State private var completed = Set<String>()
    @State private var saveError = false
    @Environment(\.dismiss) private var dismiss
    @Environment(NarrationCoordinator.self) private var voice

    var body: some View {
        NavigationStack {
            List {
                section(weeks[0])
                if weeks.count > 1 {
                    Section("Previous Weeks") {
                        ForEach(weeks.dropFirst()) { week in
                            NavigationLink {
                                List { section(week) }.navigationTitle(week.dates)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(week.dates).font(.headline)
                                    Text(week.activities.map(\.title).joined(separator: " · ")).font(.subheadline)
                                }
                            }
                            .accessibilityIdentifier("week-" + week.start)
                        }
                    }
                }
            }
            .navigationTitle("\(guide)  \(weeks[0].dates)")
            .toolbar { Button("Close") { dismiss() } }
        }
        .foregroundStyle(.primary)
        .tint(color)
        .onAppear {
            do { completed = try progress.load(default: []) }
            catch { saveError = true }
        }
        .alert("Couldn’t read or save your weekly progress.", isPresented: $saveError) { Button("OK") {} }
        .onDisappear { voice.stop() }
    }

    @ViewBuilder private func section(_ week: LessonWeek) -> some View {
        Section {
            Text(week.overview)
            Button { voice.play(week.overview) } label: { Label("Hear the recap", systemImage: "speaker.wave.2") }
        }
        Section("Play") {
            ForEach(week.activities) { activity in
                NavigationLink {
                    WeeklyRound(activity: activity, guide: guide) {
                        do {
                            var saved = try progress.load(default: [])
                            saved.insert(activity.id)
                            try progress.save(saved)
                            completed = saved
                        } catch { saveError = true }
                    }
                } label: {
                    HStack {
                        Text(activity.icon).font(.largeTitle)
                        Text(activity.title).font(.headline)
                        Spacer()
                        if completed.contains(activity.id) { Image(systemName: "checkmark.circle.fill").accessibilityLabel("Completed") }
                    }
                }
                .accessibilityIdentifier(activity.id)
                .accessibilityValue(completed.contains(activity.id) ? "Completed" : "Ready")
            }
        }
    }
}

private struct WeeklyRound: View {
    let activity: LessonActivity
    let guide: String
    let finish: () -> Void
    @Environment(NarrationCoordinator.self) private var voice
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var moved = 0
    @State private var hint = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                if index < activity.steps.count {
                    let step = activity.steps[index]
                    Text("\(guide)   \(index + 1) of \(activity.steps.count)").font(.headline)
                    Text(step.prompt).font(.title.bold()).multilineTextAlignment(.center)
                    Button { voice.play(step.spoken ?? step.prompt) } label: { Label("Listen again", systemImage: "speaker.wave.2.fill") }
                    if step.track == true {
                        HStack { ForEach(0...10, id: \.self) { position in
                            VStack { Text(moved == position ? guide : "·"); Text("\(position)") }
                        } }
                    } else {
                        Text(String(step.scene.dropLast(moved))).font(.system(size: 40))
                    }
                    if moved < (step.moves ?? 0) {
                        Button(step.track == true ? "Swim one space" : "Give one treat") {
                            moved += 1
                            voice.play("\(moved)")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        HStack {
                            ForEach(step.choices, id: \.self) { choice in
                                Button(choice) {
                                    if choice == step.answer {
                                        index += 1
                                        moved = 0
                                        hint = false
                                        if index == activity.steps.count { finish() }
                                    } else {
                                        hint = true
                                        voice.play(step.hint)
                                    }
                                }
                                .font(.title2.bold()).buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            }
                        }
                    }
                    if hint { Text(step.hint).font(.headline) }
                } else {
                    Text("\(guide)  ⭐").font(.system(size: 56))
                    Text("You finished \(activity.title)!").font(.title.bold())
                    Button("Back to the week") { dismiss() }.buttonStyle(.borderedProminent)
                }
            }.padding(28).frame(maxWidth: .infinity)
        }
        .navigationTitle(activity.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: index) { voice.play(index < activity.steps.count ? (activity.steps[index].spoken ?? activity.steps[index].prompt) : "You did it!") }
        .onDisappear { voice.stop() }
    }
}
