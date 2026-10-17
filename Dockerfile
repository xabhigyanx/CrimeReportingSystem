# ═══════════════════════════════════════════════════════════════
# Dockerfile — ShieldWatch Crime Reporting System (Vapor 4)
# Multi-stage build: compile in a full Swift SDK image,
# then copy the slim binary into a lightweight runtime image.
# ═══════════════════════════════════════════════════════════════

# ──────────────────────────────────────────────
# STAGE 1: Build
# Uses the full Swift 6.1 toolchain to resolve
# dependencies and compile an optimised release binary.
# ──────────────────────────────────────────────
FROM swift:6.1 AS build

# Install OS-level libraries that Vapor's C dependencies need at link time
RUN apt-get update && apt-get install -y \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Copy only the manifest first so Docker caches the dependency
#    resolution layer. Re-resolving only happens when Package.swift changes.
COPY Package.swift ./
RUN swift package resolve

# 2. Copy the full source tree and compile in release mode.
#    -Xswiftc flags silence concurrency-related warnings in dependencies.
COPY . .
RUN swift build \
    --configuration release \
    -Xswiftc -g

# 3. Stage the binary and its dynamic library dependencies into a
#    clean directory so we copy only what's needed to the runtime image.
RUN mkdir -p /staging/bin /staging/lib
RUN cp "$(swift build --configuration release --show-bin-path)/Run" /staging/bin/Run

# Copy Swift runtime shared libraries the binary links against
RUN ldd /staging/bin/Run | grep swift | awk '{print $3}' | xargs -I{} cp {} /staging/lib/ 2>/dev/null || true

# ──────────────────────────────────────────────
# STAGE 2: Runtime
# A slim Ubuntu image with only the shared libraries
# required to execute the compiled binary.
# ──────────────────────────────────────────────
FROM swift:6.1-slim

# Install only the minimal runtime libraries
RUN apt-get update && apt-get install -y \
    libsqlite3-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security best practices
RUN useradd --create-home --shell /bin/bash vapor
WORKDIR /app

# Copy compiled binary from the build stage
COPY --from=build /staging/bin/Run /app/Run

# Copy Leaf templates and static assets (required at runtime)
COPY Resources/ /app/Resources/
COPY Public/     /app/Public/

# Ensure the uploads directory exists and is writable
RUN mkdir -p /app/Public/uploads && chown -R vapor:vapor /app

# Switch to non-root user
USER vapor

# Expose the default Vapor port
EXPOSE 8080

# Launch the server.
# --auto-migrate creates/updates the SQLite schema on every start,
# so no separate migration step is needed in the container.
ENTRYPOINT ["/app/Run"]
CMD ["serve", "--auto-migrate"]

