import Fluent
import Vapor

// MARK: - SafetyConcernController
/// Handles community safety concerns and public alerts.
/// Enables community members to post and view safety hazards.
public struct SafetyConcernController: RouteCollection {

    // MARK: - Route Registration
    public func boot(routes: RoutesBuilder) throws {
        // --- Web Page Routes (Leaf) ---
        routes.get("concerns", use: renderConcernsFeed)
        routes.post("concerns", use: handleConcernSubmission)

        // --- REST API Endpoints (JSON for Mobile Apps) ---
        let api = routes.grouped("api", "concerns")
        api.get(use: apiGetAllConcerns)
        api.post(use: apiCreateConcern)
        api.delete(":concernID", use: apiDeleteConcern)
    }

    // MARK: - DTOs & Leaf View Contexts

    /// Decodes new safety concern form submissions
    public struct CreateConcernDTO: Content {
        public var authorName: String?
        public var area: String
        public var concernText: String
        public var urgencyLevel: String?
    }

    public struct ConcernsViewContext: Codable {
        public var title: String
        public var concerns: [SafetyConcern]
        public var totalCount: Int
        public var highUrgencyCount: Int
        public var successMessage: String?
        public var errorMessage: String?
    }

    // MARK: - Web View Handlers

    /// Renders the public Safety Concerns Community Feed (`concerns.leaf`)
    public func renderConcernsFeed(req: Request) async throws -> View {
        let successMessage = req.query[String.self, at: "success"]
        let errorMessage = req.query[String.self, at: "error"]

        // Fetch all community concerns sorted chronologically (latest first)
        let concerns = try await SafetyConcern.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()

        let highUrgencyCount = concerns.filter { $0.urgencyLevel.lowercased() == "high" }.count

        let context = ConcernsViewContext(
            title: "Community Safety Concerns Feed",
            concerns: concerns,
            totalCount: concerns.count,
            highUrgencyCount: highUrgencyCount,
            successMessage: successMessage,
            errorMessage: errorMessage
        )

        return try await req.view.render("concerns", context)
    }

    /// Handles new safety concern submissions from the web form
    public func handleConcernSubmission(req: Request) async throws -> Response {
        let form: CreateConcernDTO
        do {
            form = try req.content.decode(CreateConcernDTO.self)
        } catch {
            return req.redirect(to: "/concerns?error=Invalid+form+data.+Please+verify+inputs.")
        }

        let area = form.area.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = form.concernText.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = form.authorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let urgency = form.urgencyLevel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Medium"

        // Validation
        if area.isEmpty || text.isEmpty {
            return req.redirect(to: "/concerns?error=Please+provide+both+the+Area+and+a+Description+of+the+safety+concern.")
        }

        let concern = SafetyConcern(
            authorName: (author?.isEmpty ?? true) ? "Anonymous Citizen" : author!,
            area: area,
            concernText: text,
            urgencyLevel: urgency.isEmpty ? "Medium" : urgency
        )

        try await concern.save(on: req.db)

        return req.redirect(to: "/concerns?success=Safety+concern+successfully+posted+to+the+community+feed.")
    }

    // MARK: - REST API Endpoints

    /// GET /api/concerns - Returns list of safety alerts
    public func apiGetAllConcerns(req: Request) async throws -> [SafetyConcern] {
        try await SafetyConcern.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// POST /api/concerns - Creates a new concern via JSON
    public func apiCreateConcern(req: Request) async throws -> Response {
        let form = try req.content.decode(CreateConcernDTO.self)

        guard !form.area.isEmpty, !form.concernText.isEmpty else {
            throw Abort(.badRequest, reason: "Area and concernText are mandatory fields.")
        }

        let concern = SafetyConcern(
            authorName: form.authorName ?? "Anonymous",
            area: form.area,
            concernText: form.concernText,
            urgencyLevel: form.urgencyLevel ?? "Medium"
        )

        try await concern.save(on: req.db)
        return try await concern.encodeResponse(status: .created, for: req)
    }

    /// DELETE /api/concerns/:concernID - Deletes a concern
    public func apiDeleteConcern(req: Request) async throws -> HTTPStatus {
        guard let concern = try await SafetyConcern.find(req.parameters.get("concernID"), on: req.db) else {
            throw Abort(.notFound, reason: "Safety concern not found.")
        }
        try await concern.delete(on: req.db)
        return .noContent
    }
}

