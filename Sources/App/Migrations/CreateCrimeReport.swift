import Fluent

// MARK: - Migration: CreateCrimeReport
/// Prepares the database schema for the `crime_reports` table and its status enum.
/// Implements `AsyncMigration` using Swift's async/await concurrency.
public struct CreateCrimeReport: AsyncMigration {
    public init() { }

    /// Invoked when migrations are executed (e.g. `swift run Run migrate`)
    public func prepare(on database: Database) async throws {
        // 1. Create the database enum for case tracking status
        let statusEnum = try await database.enum("crime_status")
            .case("Pending")
            .case("Under Investigation")
            .case("Resolved")
            .create()

        // 2. Build and execute the table schema definition
        try await database.schema(CrimeReport.schema)
            .id() // Maps to primary key UUID
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("location", .string, .required)
            .field("status", statusEnum, .required)
            .field("media_path", .string)
            .field("media_type", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    /// Invoked when reverting/rolling back the database schema
    public func revert(on database: Database) async throws {
        // Drop table first, then enum type
        try await database.schema(CrimeReport.schema).delete()
        try await database.enum("crime_status").delete()
    }
}

