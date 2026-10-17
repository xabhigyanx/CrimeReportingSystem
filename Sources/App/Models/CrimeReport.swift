import Fluent
import Vapor

// MARK: - CrimeReport Model
/// Represents a reported criminal or suspicious incident in the database.
/// Uses Vapor's Fluent ORM to map Swift model properties to SQLite columns.
public final class CrimeReport: Model, Content {
    // Unique table name in SQLite
    public static let schema = "crime_reports"

    // MARK: - Status Enum
    /// Represents the investigation lifecycle status of a reported incident.
    /// Conforms to `String`, `Codable` for JSON/Leaf rendering, and `CaseIterable` for dropdowns.
    public enum ReportStatus: String, Codable, CaseIterable {
        case pending = "Pending"
        case underInvestigation = "Under Investigation"
        case resolved = "Resolved"
    }

    // MARK: - Database Columns

    /// Primary Key: Auto-generated UUID
    @ID(key: .id)
    public var id: UUID?

    /// Short title or summary of the crime (e.g., "Bicycle theft outside Library")
    @Field(key: "title")
    public var title: String

    /// Detailed description of the event, suspects, or evidence
    @Field(key: "description")
    public var description: String

    /// Geographic or campus location where the incident occurred
    @Field(key: "location")
    public var location: String

    /// Real-time case tracking status: "Pending", "Under Investigation", or "Resolved"
    @Enum(key: "status")
    public var status: ReportStatus

    /// Relative URL path to uploaded evidence file (e.g., "/uploads/uuid_evidence.jpg")
    @Field(key: "media_path")
    public var mediaPath: String?

    /// Type of uploaded media: "image", "video", or nil
    @Field(key: "media_type")
    public var mediaType: String?

    /// Automatic timestamp recording when the report was submitted
    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    /// Automatic timestamp recording when the status or details were last updated
    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    // MARK: - Initializers

    /// Empty initializer required by Fluent's internal reflection
    public init() { }

    /// Designated initializer for creating new crime reports
    public init(
        id: UUID? = nil,
        title: String,
        description: String,
        location: String,
        status: ReportStatus = .pending,
        mediaPath: String? = nil,
        mediaType: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.location = location
        self.status = status
        self.mediaPath = mediaPath
        self.mediaType = mediaType
    }
}

// MARK: - Presentation Helpers for Leaf & Views
extension CrimeReport {
    /// Formatted date string for user-friendly display in Leaf templates
    public var formattedDate: String {
        guard let createdAt = self.createdAt else { return "Just now" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Tailwind CSS badge styling classes corresponding to the case status
    public var statusBadgeClass: String {
        switch status {
        case .pending:
            return "bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-900/30 dark:text-amber-300"
        case .underInvestigation:
            return "bg-blue-100 text-blue-800 border-blue-300 dark:bg-blue-900/30 dark:text-blue-300"
        case .resolved:
            return "bg-emerald-100 text-emerald-800 border-emerald-300 dark:bg-emerald-900/30 dark:text-emerald-300"
        }
    }
}

