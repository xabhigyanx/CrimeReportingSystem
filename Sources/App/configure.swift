import Fluent
import FluentSQLiteDriver
import Leaf
import Vapor

// MARK: - Application Configuration
// This function sets up services, database connections, middleware, and route handlers.
public func configure(_ app: Application) throws {
    // 1. Enable Static File Serving Middleware
    // Serves static files directly from the `Public/` directory (e.g., CSS, JS, and user-uploaded media).
    // An uploaded file at `Public/uploads/photo.jpg` will be served at `http://localhost:8080/uploads/photo.jpg`.
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // 2. Increase Request Body Size Limit for Media Uploads
    // By default, Vapor limits body sizes to prevent DoS attacks.
    // For photo and video uploads in our crime reporting module, we allow up to 25 MB payloads.
    app.routes.defaultMaxBodySize = "25mb"

    // 2b. Bind Server to 0.0.0.0 for Docker / Cloud Deployment
    // By default Vapor only listens on 127.0.0.1 (localhost), which is unreachable
    // from outside a Docker container or cloud VM. Binding to "0.0.0.0" tells the
    // server to accept connections on all network interfaces.
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = 8080

    // 3. Configure Leaf Templating Engine
    // Leaf compiles HTML templates found in `Resources/Views/` into dynamic web pages.
    app.views.use(.leaf)

    // 4. Configure SQLite Database via Fluent ORM
    // Stores application data locally in `db.sqlite`.
    // SQLite requires zero external server setup, making it ideal for college lab demonstrations and local testing.
    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)

    // 5. Register Database Migrations
    // Migrations define the schema (tables and columns) for SQLite.
    app.migrations.add(CreateCrimeReport())
    app.migrations.add(CreateSafetyConcern())
    app.migrations.add(SeedInitialData())

    // 6. Ensure `Public/uploads` Directory Exists
    // When users upload photos or videos with incident reports, they are saved here.
    let uploadsDirectory = app.directory.publicDirectory + "uploads"
    if !FileManager.default.fileExists(atPath: uploadsDirectory) {
        try FileManager.default.createDirectory(atPath: uploadsDirectory, withIntermediateDirectories: true)
        app.logger.info("Created uploads directory at: \(uploadsDirectory)")
    }

    // 7. Register Application Routes
    // Maps URL paths (e.g. GET /dashboard, POST /reports) to controller actions.
    try routes(app)
}

