import Foundation

enum ClubType: String, CaseIterable, Codable, Identifiable {
    // Woods
    case driver = "Driver"
    case threeWood = "3 Wood"
    case fiveWood = "5 Wood"
    case sevenWood = "7 Wood"

    // Hybrids
    case twoHybrid = "2 Hybrid"
    case threeHybrid = "3 Hybrid"
    case fourHybrid = "4 Hybrid"
    case fiveHybrid = "5 Hybrid"

    // Irons
    case twoIron = "2 Iron"
    case threeIron = "3 Iron"
    case fourIron = "4 Iron"
    case fiveIron = "5 Iron"
    case sixIron = "6 Iron"
    case sevenIron = "7 Iron"
    case eightIron = "8 Iron"
    case nineIron = "9 Iron"

    // Short game
    case pitchingWedge = "PW"
    case gapWedge = "GW"
    case sandWedge = "SW"
    case lobWedge = "LW"
    case putter = "Putter"

    var id: String { rawValue }

    /// Typical loft angle in degrees
    var typicalLoft: Double {
        switch self {
        case .driver: return 10.5
        case .threeWood: return 15.0
        case .fiveWood: return 18.0
        case .sevenWood: return 21.0
        case .twoHybrid: return 17.0
        case .threeHybrid: return 19.0
        case .fourHybrid: return 22.0
        case .fiveHybrid: return 25.0
        case .twoIron: return 18.0
        case .threeIron: return 21.0
        case .fourIron: return 24.0
        case .fiveIron: return 27.0
        case .sixIron: return 30.0
        case .sevenIron: return 34.0
        case .eightIron: return 38.0
        case .nineIron: return 42.0
        case .pitchingWedge: return 46.0
        case .gapWedge: return 50.0
        case .sandWedge: return 54.0
        case .lobWedge: return 60.0
        case .putter: return 4.0
        }
    }

    /// Typical club length in inches
    var typicalLength: Double {
        switch self {
        case .driver: return 45.5
        case .threeWood: return 43.5
        case .fiveWood: return 42.5
        case .sevenWood: return 41.5
        case .twoHybrid: return 41.0
        case .threeHybrid: return 40.5
        case .fourHybrid: return 40.0
        case .fiveHybrid: return 39.5
        case .twoIron: return 39.5
        case .threeIron: return 39.0
        case .fourIron: return 38.5
        case .fiveIron: return 38.0
        case .sixIron: return 37.5
        case .sevenIron: return 37.0
        case .eightIron: return 36.5
        case .nineIron: return 36.0
        case .pitchingWedge: return 35.75
        case .gapWedge: return 35.5
        case .sandWedge: return 35.25
        case .lobWedge: return 35.0
        case .putter: return 34.0
        }
    }

    /// Target smash factor range
    var smashFactorRange: ClosedRange<Double> {
        switch self {
        case .driver: return 1.44...1.52
        case .threeWood, .fiveWood, .sevenWood: return 1.40...1.48
        case .twoHybrid, .threeHybrid, .fourHybrid, .fiveHybrid: return 1.36...1.44
        case .twoIron, .threeIron, .fourIron: return 1.33...1.41
        case .fiveIron, .sixIron, .sevenIron: return 1.30...1.38
        case .eightIron, .nineIron: return 1.28...1.36
        case .pitchingWedge, .gapWedge: return 1.25...1.33
        case .sandWedge, .lobWedge: return 1.22...1.30
        case .putter: return 1.0...1.05
        }
    }

    /// Category for grouping
    var category: String {
        switch self {
        case .driver, .threeWood, .fiveWood, .sevenWood:
            return "Woods"
        case .twoHybrid, .threeHybrid, .fourHybrid, .fiveHybrid:
            return "Hybrids"
        case .twoIron, .threeIron, .fourIron, .fiveIron, .sixIron, .sevenIron, .eightIron, .nineIron:
            return "Irons"
        case .pitchingWedge, .gapWedge, .sandWedge, .lobWedge:
            return "Wedges"
        case .putter:
            return "Putter"
        }
    }

    var systemIconName: String {
        switch category {
        case "Woods": return "figure.golf"
        case "Hybrids": return "figure.golf"
        case "Irons": return "figure.golf"
        case "Wedges": return "figure.golf"
        default: return "circle.fill"
        }
    }
}
