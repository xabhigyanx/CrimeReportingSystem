import Fluent
import Vapor

// MARK: - Migration: SeedInitialData
/// Seeds sample crime reports and safety alerts so the application
/// presents functional data immediately upon initial launch during demonstrations.
public struct SeedInitialData: AsyncMigration {
    public init() { }

    public func prepare(on database: Database) async throws {
        // Sample Crime Reports
        let sampleReports = [
            CrimeReport(
                title: "Laptop Theft at Central Library 2nd Floor",
                description: "MacBook Pro M2 space gray left momentarily on study desk near the west window was taken between 3:15 PM and 3:30 PM.",
                location: "Central Library, Level 2 Quiet Study Wing",
                status: .underInvestigation
            ),
            CrimeReport(
                title: "Vandalism and Graffiti on Science Block Wall",
                description: "Spray paint vandalism discovered on the north exterior facade of the Chemistry Building overnight.",
                location: "Science Complex, Chemistry Block North",
                status: .pending
            ),
            CrimeReport(
                title: "Stolen Bicycle Recovered Near Metro Station",
                description: "Trek mountain bike reported missing 3 days ago was located and verified by campus security. Suspect identified through security cameras.",
                location: "South Gate Bike Racks & Metro Plaza",
                status: .resolved
            ),
            CrimeReport(
                title: "Suspicious Individual Lurking Around East Dormitory",
                description: "Non-resident individual seen attempting to open ground-floor patio doors around 11:45 PM.",
                location: "East Residential Block C",
                status: .underInvestigation
            )
        ]

        for report in sampleReports {
            try await report.save(on: database)
        }

        // Sample Community Safety Concerns
        let sampleConcerns = [
            SafetyConcern(
                authorName: "Sarah M. (Student Council)",
                area: "West Campus Pathway towards Bus Terminal",
                concernText: "Multiple street lamps are completely dark along the tree-lined walkway, creating a significant hazard for evening students.",
                urgencyLevel: "High"
            ),
            SafetyConcern(
                authorName: "Anonymous Faculty",
                area: "Engineering Parking Lot B",
                concernText: "Speeding vehicles observed near the pedestrian crossing during morning peak hours (8:30 AM - 9:15 AM). Needs speed bumps.",
                urgencyLevel: "Medium"
            ),
            SafetyConcern(
                authorName: "Campus Cycling Club",
                area: "Perimeter Jogging Track",
                concernText: "Loose gravel and overgrown tree branches obscuring blind corners for cyclists and runners.",
                urgencyLevel: "Low"
            )
        ]

        for concern in sampleConcerns {
            try await concern.save(on: database)
        }
    }

    public func revert(on database: Database) async throws {
        try await CrimeReport.query(on: database).delete()
        try await SafetyConcern.query(on: database).delete()
    }
}

