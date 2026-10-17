import Fluent

// MARK: - Migration: CreateSafetyConcern
/// Prepares the database schema for the community `safety_concerns` table.
public struct CreateSafetyConcern: AsyncMigration {
    public init() { }

    /// Creates the `safety_concerns` table with necessary columns
    public func prepare(on database: Database) async throws {
        try await database.schema(SafetyConcern.schema)
            .id()
            .field("author_name", .string, .required)
            .field("area", .string, .required)
            .field("concern_text", .string, .required)
            .field("urgency_level", .string, .required)
            .field("created_at", .datetime)
            .create()
    }

    /// Drops the `safety_concerns` table on rollback
    public func revert(on database: Database) async throws {
        try await database.schema(SafetyConcern.schema).delete()
    }
}

