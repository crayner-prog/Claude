import Foundation

struct GolfSession: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date
    var shots: [ShotData]
    var notes: String

    init(id: UUID = UUID(), name: String = "", date: Date = Date(),
         shots: [ShotData] = [], notes: String = "") {
        self.id = id
        self.name = name.isEmpty ? "Session \(Self.dateFormatter.string(from: date))" : name
        self.date = date
        self.shots = shots
        self.notes = notes
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    // MARK: - Aggregate Stats

    var averageMetrics: LaunchMetrics? {
        guard !shots.isEmpty else { return nil }
        let count = Double(shots.count)
        return LaunchMetrics(
            ballSpeed: shots.map(\.metrics.ballSpeed).reduce(0, +) / count,
            clubSpeed: shots.map(\.metrics.clubSpeed).reduce(0, +) / count,
            smashFactor: shots.map(\.metrics.smashFactor).reduce(0, +) / count,
            spinRate: shots.map(\.metrics.spinRate).reduce(0, +) / count,
            spinAxis: shots.map(\.metrics.spinAxis).reduce(0, +) / count,
            launchAngle: shots.map(\.metrics.launchAngle).reduce(0, +) / count,
            launchDirection: shots.map(\.metrics.launchDirection).reduce(0, +) / count,
            clubPath: shots.map(\.metrics.clubPath).reduce(0, +) / count,
            faceAngle: shots.map(\.metrics.faceAngle).reduce(0, +) / count,
            attackAngle: shots.map(\.metrics.attackAngle).reduce(0, +) / count,
            carryDistance: shots.map(\.metrics.carryDistance).reduce(0, +) / count,
            confidence: MetricConfidence()
        )
    }

    var maxBallSpeed: Double? {
        shots.map(\.metrics.ballSpeed).max()
    }

    var maxClubSpeed: Double? {
        shots.map(\.metrics.clubSpeed).max()
    }

    var maxCarry: Double? {
        shots.map(\.metrics.carryDistance).max()
    }

    var shotsPerClub: [ClubType: [ShotData]] {
        Dictionary(grouping: shots, by: \.club)
    }

    var shotShapeDistribution: [ShotShape: Int] {
        var dist: [ShotShape: Int] = [:]
        for shot in shots {
            dist[shot.shotShape, default: 0] += 1
        }
        return dist
    }
}

// MARK: - Session Store

import Combine

@MainActor
class SessionStore: ObservableObject {
    @Published var sessions: [GolfSession] = []
    @Published var currentSession: GolfSession?

    private let storageKey = "golf_sessions"

    init() {
        load()
    }

    func startNewSession(name: String = "") {
        currentSession = GolfSession(name: name)
    }

    func addShot(_ shot: ShotData) {
        if currentSession == nil {
            startNewSession()
        }
        currentSession?.shots.append(shot)
    }

    func finalizeCurrentSession() {
        guard let session = currentSession, !session.shots.isEmpty else {
            currentSession = nil
            return
        }
        sessions.insert(session, at: 0)
        currentSession = nil
        save()
    }

    func deleteSession(_ session: GolfSession) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func deleteShot(_ shot: ShotData, from session: GolfSession) {
        if let idx = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[idx].shots.removeAll { $0.id == shot.id }
            save()
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([GolfSession].self, from: data) {
            sessions = decoded
        }
    }
}
