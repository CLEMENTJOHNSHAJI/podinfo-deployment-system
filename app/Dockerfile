# Multi-stage Dockerfile for Podinfo application
# Stage 1: Build
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy go.mod only (go.sum will be generated during download)
COPY go.mod ./

# Download dependencies (this will generate go.sum)
RUN go mod download

# Copy source code
COPY . .

# Ensure module graph is up-to-date and go.sum is generated
RUN go mod tidy

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o podinfo .

# Stage 2: Runtime
FROM alpine:3.18

# Create non-root user
RUN addgroup -g 1001 -S podinfo && \
    adduser -u 1001 -S podinfo -G podinfo

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata curl

# Copy binary from builder stage
COPY --from=builder /app/podinfo /usr/local/bin/podinfo

# Create app directory and set ownership
RUN mkdir -p /app && chown -R podinfo:podinfo /app

# Switch to non-root user
USER podinfo

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/healthz || exit 1

# Run the application
CMD ["podinfo"]
