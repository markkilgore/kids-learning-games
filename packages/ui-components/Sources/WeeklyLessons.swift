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

struct LessonStep: Decodable, Equatable {
    let spoken: String?
    let prompt: String
    let scene: String
    let choices: [String]
    let answer: String
    let hint: String
    let moves: Int?
    let track: Bool?
}

/// Lines the weekly player speaks itself. Keep in step with `weeklySharedLines` in tools/lib/lines.mjs.
public enum WeeklySpokenLines {
    public static let counts = ["One!", "Two!", "Three!", "Four!", "Five!", "Six!", "Seven!", "Eight!", "Nine!", "Ten!"]
    public static let praise = ["Great job!", "You got it!", "Nice thinking!", "Yes! That is right."]
    public static let finished = "You did it!"
    public static let all = counts + praise + [finished]
}

public struct WeeklyLessonsButton: View {
    private let weeks: [LessonWeek]
    private let guide: String
    private let color: Color
    private let progress: NamespacedProgressStore<Set<String>>?
    @State private var showing = false

    public init(resource: String, namespace: String, guide: String, color: Color) {
        self.guide = guide
        self.color = color
        progress = try? NamespacedProgressStore(namespace: namespace, fileName: "weekly-lessons.json")
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
            if let latest = available.first, let progress {
                Button { showing = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar")
                        VStack(alignment: .leading, spacing: 0) {
                            Text(latest.homeTitle(on: today))
                            Text(latest.dates).font(.kidLabel).opacity(0.85)
                        }
                    }
                }
                .buttonStyle(KidButtonStyle(tint: color, compact: true))
                .accessibilityIdentifier("weekly-home")
                .fullScreenCover(isPresented: $showing) {
                    WeeklyShelf(weeks: available, guide: guide, color: color, progress: progress)
                }
            }
        }
    }
}

/// Remembers where a child stopped inside an activity until the app closes.
@MainActor
private enum WeeklyResume {
    static var steps: [String: Int] = [:]
}

private struct WeeklyShelf: View {
    let weeks: [LessonWeek]
    let guide: String
    let color: Color
    let progress: NamespacedProgressStore<Set<String>>
    @State private var completed = Set<String>()
    @State private var saveError = false
    @State private var weekID: String?
    @State private var activity: LessonActivity?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.kidTheme) private var theme
    @Environment(NarrationCoordinator.self) private var voice

    private var week: LessonWeek { weeks.first { $0.id == weekID } ?? weeks[0] }

    var body: some View {
        ZStack {
            theme.backdrop.ignoresSafeArea()
            if let activity {
                WeeklyRound(activity: activity, guide: guide, color: color) {
                    markCompleted(activity)
                } onBack: {
                    voice.stop()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { self.activity = nil }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                shelf.transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .foregroundStyle(theme.ink)
        .onAppear {
            do { completed = try progress.load(default: []) }
            catch { saveError = true }
        }
        .alert("Couldn’t read or save your weekly progress.", isPresented: $saveError) { Button("OK") {} }
        .onDisappear { voice.stop() }
    }

    private var shelf: some View {
        VStack(spacing: 18) {
            KidTopBar(
                "\(guide)  \(week.id == weeks[0].id ? "This week at school" : "An earlier week")",
                subtitle: week.dates,
                back: week.id == weeks[0].id
                    ? KidBackButton { dismiss() }
                    : KidBackButton("Latest week", systemImage: "chevron.left") { withAnimation { weekID = nil } }
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 16) {
                        Text(week.overview)
                            .font(.kidBody)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button { voice.play(week.overview) } label: { Label("Hear the recap", systemImage: "speaker.wave.2.fill") }
                            .buttonStyle(KidButtonStyle(.soft, tint: color, compact: true))
                    }
                    .padding(20)
                    .kidCard()

                    HStack(spacing: 18) {
                        ForEach(week.activities) { activity in
                            let done = completed.contains(activity.id)
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { self.activity = activity }
                            } label: {
                                VStack(spacing: 12) {
                                    Text(activity.icon).font(.system(size: 72))
                                    Text(activity.title)
                                        .font(.kidHeadline)
                                        .multilineTextAlignment(.center)
                                    Label(done ? "Finished" : "Play", systemImage: done ? "checkmark.seal.fill" : "play.fill")
                                        .font(.kidLabel)
                                        .foregroundStyle(theme.isDark ? .yellow : (done ? theme.success : color))
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity, minHeight: 230)
                                .kidCard(.raised, radius: KidTheme.Radius.large)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityIdentifier(activity.id)
                            .accessibilityLabel(activity.title)
                            .accessibilityValue(done ? "Completed" : "Ready")
                        }
                    }

                    if week.id == weeks[0].id, weeks.count > 1 {
                        Text("Previous Weeks").font(.kidHeadline)
                        HStack(spacing: 12) {
                            ForEach(weeks.dropFirst()) { earlier in
                                Button { withAnimation { weekID = earlier.id } } label: {
                                    Label(earlier.dates, systemImage: "clock.arrow.circlepath")
                                }
                                .buttonStyle(KidButtonStyle(.soft, tint: color, compact: true))
                                .accessibilityIdentifier("week-" + earlier.start)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(28)
    }

    private func markCompleted(_ activity: LessonActivity) {
        do {
            var saved = try progress.load(default: [])
            saved.insert(activity.id)
            try progress.save(saved)
            completed = saved
        } catch { saveError = true }
    }
}

private struct WeeklyRound: View {
    let activity: LessonActivity
    let guide: String
    let color: Color
    let finish: () -> Void
    let onBack: () -> Void
    @Environment(NarrationCoordinator.self) private var voice
    @Environment(FeedbackPlayer.self) private var feedback: FeedbackPlayer?
    @Environment(\.kidTheme) private var theme
    @State private var index: Int
    @State private var moved = 0
    @State private var wrongChoice: String?
    @State private var praise: String?
    @State private var celebration = 0
    @Namespace private var trackSpace

    init(activity: LessonActivity, guide: String, color: Color, finish: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.activity = activity
        self.guide = guide
        self.color = color
        self.finish = finish
        self.onBack = onBack
        _index = State(initialValue: min(WeeklyResume.steps[activity.id] ?? 0, activity.steps.count - 1))
    }

    private var isFinished: Bool { index >= activity.steps.count }

    var body: some View {
        VStack(spacing: 20) {
            KidTopBar(activity.title, back: KidBackButton("Back", systemImage: "chevron.left", action: onBack)) {
                if !isFinished {
                    HStack(spacing: 8) {
                        ForEach(activity.steps.indices, id: \.self) { step in
                            Circle()
                                .fill(step < index ? theme.success : step == index ? color : theme.ink.opacity(0.2))
                                .frame(width: 18, height: 18)
                        }
                    }
                    .accessibilityLabel("Step \(index + 1) of \(activity.steps.count)")
                }
            }

            if isFinished {
                finishedCard
            } else {
                stepCard(activity.steps[index])
            }
        }
        .padding(28)
        .overlay { CelebrationView(trigger: celebration) }
        .task(id: index) {
            voice.play(isFinished ? WeeklySpokenLines.finished : (activity.steps[index].spoken ?? activity.steps[index].prompt))
        }
        .onDisappear { voice.stop() }
    }

    private var finishedCard: some View {
        VStack(spacing: 22) {
            Text("\(guide) ⭐").font(.system(size: 96))
            Text("You finished \(activity.title)!")
                .font(.kidDisplay)
                .multilineTextAlignment(.center)
            Button("Back to the week", action: onBack)
                .buttonStyle(KidButtonStyle(tint: theme.success))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidCard(radius: KidTheme.Radius.large)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private func stepCard(_ step: LessonStep) -> some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                Text(step.prompt)
                    .font(.kidTitle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { voice.play(step.spoken ?? step.prompt) } label: { Label("Listen again", systemImage: "speaker.wave.2.fill") }
                    .buttonStyle(KidButtonStyle(.soft, tint: color, compact: true))
            }

            Group {
                if step.track == true { track } else { scene(step) }
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding(.vertical, 8)
            .kidCard(.quiet)

            if let praise {
                Label(praise, systemImage: "star.fill")
                    .font(.kidDisplay)
                    .foregroundStyle(theme.success)
                    .frame(minHeight: 110)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            } else if moved < (step.moves ?? 0) {
                Button(step.track == true ? "Swim one space" : "Give one treat") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { moved += 1 }
                    feedback?.play(.pop)
                    voice.play(WeeklySpokenLines.counts[min(moved, WeeklySpokenLines.counts.count) - 1])
                }
                .buttonStyle(KidButtonStyle(tint: color))
                .frame(minHeight: 110)
            } else {
                HStack(spacing: 16) {
                    ForEach(step.choices, id: \.self) { choice in
                        AnswerTile(state: choice == wrongChoice ? .wrong : .idle, tint: color) {
                            choose(choice, in: step)
                        } label: {
                            Text(choice)
                                .font(.system(size: choice.count <= 2 ? 56 : 28, weight: .heavy, design: .rounded))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.6)
                        }
                        .accessibilityLabel(choice)
                    }
                }
                .frame(minHeight: 110)
            }

            if wrongChoice != nil, praise == nil {
                Label(step.hint, systemImage: "lightbulb.fill")
                    .font(.kidHeadline)
                    .multilineTextAlignment(.center)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .kidCard(radius: KidTheme.Radius.large)
        .id(index)
        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
    }

    private var track: some View {
        HStack(spacing: 6) {
            ForEach(0...10, id: \.self) { position in
                VStack(spacing: 6) {
                    ZStack {
                        if moved == position {
                            Text(guide)
                                .font(.system(size: 46))
                                .matchedGeometryEffect(id: "guide", in: trackSpace)
                        }
                    }
                    .frame(height: 56)
                    Text("\(position)")
                        .font(.kidHeadline)
                        .frame(width: 52, height: 52)
                        .background(position <= moved ? color.opacity(0.55) : theme.ink.opacity(0.12), in: Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder private func scene(_ step: LessonStep) -> some View {
        if step.moves == nil {
            Text(step.scene).font(.system(size: 76))
        } else {
            let items = Array(step.scene)
            HStack(spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                    Text(String(item))
                        .font(.system(size: 60))
                        .scaleEffect(offset < items.count - moved ? 1 : 0.2)
                        .opacity(offset < items.count - moved ? 1 : 0)
                }
            }
            .accessibilityLabel("\(items.count - moved) left")
        }
    }

    private func choose(_ choice: String, in step: LessonStep) {
        guard praise == nil else { return }
        guard choice == step.answer else {
            feedback?.play(.wrong)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { wrongChoice = choice }
            voice.play(step.hint)
            return
        }
        feedback?.play(.correct)
        let line = WeeklySpokenLines.praise[index % WeeklySpokenLines.praise.count]
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { praise = line }
        voice.play(line)
        let answered = index
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1_300))
            guard index == answered else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                index += 1
                moved = 0
                wrongChoice = nil
                praise = nil
            }
            if isFinished {
                WeeklyResume.steps[activity.id] = nil
                finish()
                feedback?.play(.celebrate)
                celebration += 1
            } else {
                WeeklyResume.steps[activity.id] = index
            }
        }
    }
}
