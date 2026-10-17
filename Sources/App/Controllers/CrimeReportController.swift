import Fluent
import Vapor

// MARK: - CrimeReportController
/// Handles all business logic and HTTP requests related to Crime Reports.
/// Implements both web frontend rendering (Leaf) and RESTful API endpoints.
public struct CrimeReportController: RouteCollection {

    // MARK: - Route Registration
    /// Registers endpoints onto the Vapor application router.
    /// Vapor calls this method during server configuration in `routes.swift`.
    public func boot(routes: RoutesBuilder) throws {
        // --- Web Page Routes (HTML via Leaf) ---
        routes.get(use: renderHome)
        routes.get("report", use: renderReportForm)
        routes.post("report", use: handleReportSubmission)
        routes.get("dashboard", use: renderDashboard)
        routes.post("reports", ":reportID", "status", use: handleStatusUpdate)

        // --- REST API Endpoints (JSON for iOS Client / Mobile Apps) ---
        let api = routes.grouped("api", "reports")
        api.get(use: apiGetAllReports)
        api.post(use: apiCreateReport)
        api.get(":reportID", use: apiGetReportDetail)
        api.patch(":reportID", "status", use: apiUpdateStatus)
        api.delete(":reportID", use: apiDeleteReport)
    }

    // MARK: - Data Transfer Objects (DTOs)

    /// Decodes multipart/form-data received from the incident report web form.
    public struct CreateReportDTO: Content {
        public var title: String
        public var description: String
        public var location: String
        public var media: Vapor.File?
    }

    /// Decodes status update forms and JSON patches.
    public struct UpdateStatusDTO: Content {
        public var status: CrimeReport.ReportStatus
    }

    /// Statistics container passed to Leaf templates for dashboard analytics.
    public struct DashboardStats: Codable {
        public var total: Int
        public var pending: Int
        public var investigating: Int
        public var resolved: Int
    }

    // MARK: - View Contexts for Leaf Templates

    public struct HomeViewContext: Codable {
        public var title: String
        public var stats: DashboardStats
        public var recentReports: [CrimeReport]
        public var recentConcerns: [SafetyConcern]
    }

    public struct ReportFormViewContext: Codable {
        public var title: String
        public var errorMessage: String?
        public var successMessage: String?
    }

    public struct DashboardViewContext: Codable {
        public var title: String
        public var reports: [CrimeReport]
        public var stats: DashboardStats
        public var selectedStatus: String?
        public var searchQuery: String?
        public var successMessage: String?
        public var errorMessage: String?
    }

    // MARK: - Frontend View Handlers

    /// Renders the Home / Landing page (`index.leaf`) with key statistics and recent activity.
    public func renderHome(req: Request) async throws -> View {
        // Fluent Query 1: Fetch 4 most recent crime reports sorted by submission date
        let recentReports = try await CrimeReport.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .range(0..<4)
            .all()

        // Fluent Query 2: Fetch 3 most recent community safety alerts
        let recentConcerns = try await SafetyConcern.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .range(0..<3)
            .all()

        // Fluent Query 3: Compute aggregate counts for the live metrics counters
        let total = try await CrimeReport.query(on: req.db).count()
        let pending = try await CrimeReport.query(on: req.db).filter(\.$status == .pending).count()
        let investigating = try await CrimeReport.query(on: req.db).filter(
            \.$status == .underInvestigation
        ).count()
        let resolved = try await CrimeReport.query(on: req.db).filter(\.$status == .resolved)
            .count()

        let stats = DashboardStats(
            total: total,
            pending: pending,
            investigating: investigating,
            resolved: resolved
        )

        let context = HomeViewContext(
            title: "Campus & Community Crime Reporting System",
            stats: stats,
            recentReports: recentReports,
            recentConcerns: recentConcerns
        )

        return try await req.view.render("index", context)
    }

    /// Renders the incident submission form page (`report.leaf`).
    public func renderReportForm(req: Request) async throws -> View {
        let errorMessage = req.query[String.self, at: "error"]
        let successMessage = req.query[String.self, at: "success"]

        let context = ReportFormViewContext(
            title: "Submit Incident Report",
            errorMessage: errorMessage,
            successMessage: successMessage
        )

        return try await req.view.render("report", context)
    }

    /// Handles multipart form submissions from `report.leaf`.
    /// Performs server-side validation, saves media files to `Public/uploads`, and creates the database record.
    public func handleReportSubmission(req: Request) async throws -> Response {
        let form: CreateReportDTO
        do {
            form = try req.content.decode(CreateReportDTO.self)
        } catch {
            return req.redirect(to: "/report?error=Invalid+form+submission.+Please+try+again.")
        }

        // Server-Side Input Validation
        let title = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = form.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = form.location.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty || description.isEmpty || location.isEmpty {
            return req.redirect(
                to:
                    "/report?error=Please+fill+in+all+required+fields+(Title,+Description,+Location)."
            )
        }

        // Multipart File Upload Processing
        var savedMediaPath: String? = nil
        var detectedMediaType: String? = nil

        if let file = form.media, !file.filename.isEmpty, file.data.readableBytes > 0 {
            do {
                let uploadResult = try await saveUploadedFile(file: file, on: req)
                savedMediaPath = uploadResult.relativePath
                detectedMediaType = uploadResult.mediaType
            } catch {
                req.logger.error("Failed to upload file: \(error.localizedDescription)")
                return req.redirect(
                    to:
                        "/report?error=Failed+to+save+uploaded+media.+Please+try+a+standard+image+or+video+file."
                )
            }
        }

        // Save new CrimeReport via Fluent ORM
        let report = CrimeReport(
            title: title,
            description: description,
            location: location,
            status: .pending,
            mediaPath: savedMediaPath,
            mediaType: detectedMediaType
        )

        try await report.save(on: req.db)

        // Redirect user to the dashboard with a success message
        return req.redirect(
            to:
                "/dashboard?success=Crime+report+submitted+successfully.+Case+tracking+is+now+active."
        )
    }

    /// Renders the Case Tracking Dashboard (`dashboard.leaf`) with filters and status transition controls.
    public func renderDashboard(req: Request) async throws -> View {
        let selectedStatus = req.query[String.self, at: "status"]
        let searchQuery = req.query[String.self, at: "q"]
        let successMessage = req.query[String.self, at: "success"]
        let errorMessage = req.query[String.self, at: "error"]

        // Compute dashboard analytics
        let total = try await CrimeReport.query(on: req.db).count()
        let pending = try await CrimeReport.query(on: req.db).filter(\.$status == .pending).count()
        let investigating = try await CrimeReport.query(on: req.db).filter(
            \.$status == .underInvestigation
        ).count()
        let resolved = try await CrimeReport.query(on: req.db).filter(\.$status == .resolved)
            .count()

        let stats = DashboardStats(
            total: total,
            pending: pending,
            investigating: investigating,
            resolved: resolved
        )

        // Build Fluent query dynamically based on search and status filters
        var query = CrimeReport.query(on: req.db)

        if let filterStatus = selectedStatus, !filterStatus.isEmpty, filterStatus != "all" {
            if let enumStatus = CrimeReport.ReportStatus(rawValue: filterStatus) {
                query = query.filter(\.$status == enumStatus)
            }
        }

        if let search = searchQuery, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
            query = query.group(.or) { group in
                group.filter(\.$title ~~ term)
                group.filter(\.$description ~~ term)
                group.filter(\.$location ~~ term)
            }
        }

        let reports =
            try await query
            .sort(\.$createdAt, .descending)
            .all()

        let context = DashboardViewContext(
            title: "Case Tracking Dashboard",
            reports: reports,
            stats: stats,
            selectedStatus: selectedStatus ?? "all",
            searchQuery: searchQuery,
            successMessage: successMessage,
            errorMessage: errorMessage
        )

        return try await req.view.render("dashboard", context)
    }

    /// Updates the status of an existing case from the dashboard dropdown form.
    public func handleStatusUpdate(req: Request) async throws -> Response {
        guard let reportID = req.parameters.get("reportID", as: UUID.self) else {
            return req.redirect(to: "/dashboard?error=Invalid+case+ID.")
        }

        guard let report = try await CrimeReport.find(reportID, on: req.db) else {
            return req.redirect(to: "/dashboard?error=Case+report+not+found.")
        }

        let updateDTO = try req.content.decode(UpdateStatusDTO.self)
        report.status = updateDTO.status
        try await report.save(on: req.db)

        return req.redirect(
            to:
                "/dashboard?success=Case+\(report.title.prefix(20))...+status+updated+to+\(updateDTO.status.rawValue)."
        )
    }

    // MARK: - File Upload Helper
    /// Sanitizes the upload filename, determines media type, and writes the byte buffer to `Public/uploads`.
    private func saveUploadedFile(file: Vapor.File, on req: Request) async throws -> (
        relativePath: String, mediaType: String
    ) {
        // 1. Sanitize the extension to prevent path traversal
        let fileExtension = (file.extension ?? (file.filename as NSString).pathExtension)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }

        let imageExtensions = ["jpg", "jpeg", "png", "gif", "webp", "heic"]
        let videoExtensions = ["mp4", "mov", "avi", "webm", "m4v"]

        let mediaType: String
        if imageExtensions.contains(fileExtension) {
            mediaType = "image"
        } else if videoExtensions.contains(fileExtension) {
            mediaType = "video"
        } else {
            mediaType = "image"  // Default fallback
        }

        // 2. Generate unique filename using UUID to prevent collisions
        let safeExtension = fileExtension.isEmpty ? "jpg" : fileExtension
        let uniqueFilename = "\(UUID().uuidString).\(safeExtension)"

        // 3. Form destination path in Public/uploads
        let publicDir = req.application.directory.publicDirectory
        let uploadsDir = publicDir + "uploads"

        if !FileManager.default.fileExists(atPath: uploadsDir) {
            try FileManager.default.createDirectory(
                atPath: uploadsDir, withIntermediateDirectories: true)
        }

        let destinationPath = uploadsDir + "/" + uniqueFilename

        // 4. Write data to disk using NIO FileIO
        try await req.fileio.writeFile(file.data, at: destinationPath)

        let relativePath = "/uploads/" + uniqueFilename
        return (relativePath, mediaType)
    }

    // MARK: - REST API Endpoints (iOS Client Support)

    /// GET /api/reports - Returns JSON list of all reports
    public func apiGetAllReports(req: Request) async throws -> [CrimeReport] {
        try await CrimeReport.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    /// POST /api/reports - Creates a report via JSON or multipart
    public func apiCreateReport(req: Request) async throws -> Response {
        let form = try req.content.decode(CreateReportDTO.self)

        guard !form.title.isEmpty, !form.description.isEmpty, !form.location.isEmpty else {
            throw Abort(
                .badRequest, reason: "Title, description, and location fields are required.")
        }

        var mediaPath: String? = nil
        var mediaType: String? = nil

        if let file = form.media, !file.filename.isEmpty, file.data.readableBytes > 0 {
            let result = try await saveUploadedFile(file: file, on: req)
            mediaPath = result.relativePath
            mediaType = result.mediaType
        }

        let report = CrimeReport(
            title: form.title,
            description: form.description,
            location: form.location,
            status: .pending,
            mediaPath: mediaPath,
            mediaType: mediaType
        )

        try await report.save(on: req.db)
        return try await report.encodeResponse(status: .created, for: req)
    }

    /// GET /api/reports/:reportID - Returns JSON of a single report
    public func apiGetReportDetail(req: Request) async throws -> CrimeReport {
        guard let report = try await CrimeReport.find(req.parameters.get("reportID"), on: req.db)
        else {
            throw Abort(.notFound, reason: "Crime report with specified ID was not found.")
        }
        return report
    }

    /// PATCH /api/reports/:reportID/status - Updates report status
    public func apiUpdateStatus(req: Request) async throws -> CrimeReport {
        guard let report = try await CrimeReport.find(req.parameters.get("reportID"), on: req.db)
        else {
            throw Abort(.notFound, reason: "Crime report with specified ID was not found.")
        }
        let updateDTO = try req.content.decode(UpdateStatusDTO.self)
        report.status = updateDTO.status
        try await report.save(on: req.db)
        return report
    }

    /// DELETE /api/reports/:reportID - Removes a report from database
    public func apiDeleteReport(req: Request) async throws -> HTTPStatus {
        guard let report = try await CrimeReport.find(req.parameters.get("reportID"), on: req.db)
        else {
            throw Abort(.notFound, reason: "Crime report with specified ID was not found.")
        }
        try await report.delete(on: req.db)
        return .noContent
    }
}
