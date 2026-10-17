import App
import Vapor

// MARK: - Application Entry Point
// This file initializes the Vapor application lifecycle.
// It detects the current execution environment (development, production, or testing),
// bootstraps logging, runs initial configurations, and starts listening for HTTP traffic.

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)

let app = Application(env)
defer { 
    // Ensure all database connections, event loops, and resources shut down gracefully.
    app.shutdown() 
}

// Load custom application configuration (Leaf views, SQLite DB, routes, and migrations)
try configure(app)

// Start the HTTP server (default on http://127.0.0.1:8080)
try app.run()

