import Fluent
import Vapor

// MARK: - SafetyConcern Model
/// Represents a community safety alert or public hazard notification.
/// Allows campus and neighborhood members to raise general safety warnings.
public final class SafetyConcern: Model, Content {
    // Unique table name in SQLite
    public static let schema = "safety_concerns"

    // MARK: - Database Columns

    /// Primary Key: Auto-generated UUID
    @ID(key: .id)
    public var id: UUID?

    /// Name or handle of the person reporting (or "Anonymous Citizen")
    @Field(key: "author_name")
    public var authorName: String

    /// Physical neighborhood, sector, or campus zone
    @Field(key: "area")
    public var area: String

    /// Description of the safety concern or hazard
    @Field(key: "concern_text")
    public var concernText: String

    /// Severity level of the concern ("Low", "Medium", "High")
    @Field(key: "urgency_level")
    public var urgencyLevel: String

    /// Automatic timestamp when the alert was published
    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    // MARK: - Initializers

    /// Empty initializer required by Fluent
    public init() { }

    /// Designated initializer
    public init(
        id: UUID? = nil,
        authorName: String,
        area: String,
        concernText: String,
        urgencyLevel: String = "Medium"
    ) {
        self.id = id
        self.authorName = authorName
        self.area = area
        self.concernText = concernText
        self.urgencyLevel = urgencyLevel
    }
}

// MARK: - Presentation Helpers for Leaf
extension SafetyConcern {
    /// Formatted date string for user-friendly display in Leaf templates
    public var formattedDate: String {
        guard let createdAt = self.createdAt else { return "Just now" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    /// Color-coded CSS badge class based on urgency level
    public var urgencyBadgeClass: String {
        switch urgencyLevel.lowercased() {
        case "high":
            return "bg-rose-100 text-rose-800 border-rose-300 dark:bg-rose-900/40 dark:text-rose-300"
        case "medium":
            return "bg-amber-100 text-amber-800 border-amber-300 dark:bg-amber-900/40 dark:text-amber-300"
        default:
            return "bg-emerald-100 text-emerald-800 border-emerald-300 dark:bg-emerald-900/40 dark:text-emerald-300"
        }
    }
}

