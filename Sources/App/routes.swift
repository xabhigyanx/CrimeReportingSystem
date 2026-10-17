import Fluent
import Vapor

// MARK: - Application Routes Setup
/// Registers all application routes and binds URL endpoints to their respective controllers.
///
/// ### Vapor Routing Fundamentals (For College Lab Viva/Explanation):
/// 1. **Route Collections**: Instead of cluttering `routes.swift` with dozens of closures,
///    we group related routes into `RouteCollection` structs (`CrimeReportController` & `SafetyConcernController`).
/// 2. **HTTP Verbs**:
///    - `GET`: Used for retrieving resources or rendering Leaf HTML views.
///    - `POST`: Used for submitting forms (multipart or url-encoded) and creating database records.
///    - `PATCH`: Used for updating partial attributes (e.g. changing report status from Pending to Resolved).
///    - `DELETE`: Used for removing records.
/// 3. **Dynamic Route Parameters**: Defined using `:parameterName` (e.g., `:reportID`).
///    Inside the controller, `req.parameters.get("reportID", as: UUID.self)` parses and validates the type safely.
/// 4. **Fluent Database Access**: Within any route handler, `req.db` provides a handle to the
///    connected SQLite database instance, executing non-blocking asynchronous queries (`await Model.query(on: req.db)`).
public func routes(_ app: Application) throws {
    // MARK: - Health Check Route
    // A quick endpoint to verify server status and network reachability.
    app.get("health") { req async -> [String: String] in
        ["status": "online", "system": "Crime Reporting & Safety System"]
    }

    // MARK: - Crime Report Module Routes
    // Maps Home, Incident Submission, Case Dashboard, and Report APIs
    try app.register(collection: CrimeReportController())

    // MARK: - Safety Concerns Module Routes
    // Maps Community Safety Feed and Alert APIs
    try app.register(collection: SafetyConcernController())
}

