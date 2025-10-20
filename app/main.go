package main

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Application configuration
type Config struct {
	Port        string
	Environment string
	LogLevel    string
	Version     string
	BuildTime   string
	Commit      string
	SecretARN   string
}

// Secrets structure
type Secrets struct {
	SuperSecretToken string `json:"SUPER_SECRET_TOKEN"`
	DatabaseURL      string `json:"DATABASE_URL"`
	APIKey          string `json:"API_KEY"`
}

// Global variables
var (
	config  Config
	secrets Secrets
)

// Application metrics
var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint", "status"},
	)

	httpRequestDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "HTTP request duration in seconds",
			Buckets: prometheus.DefBuckets,
		},
		[]string{"method", "endpoint"},
	)

	applicationHealth = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "application_health",
			Help: "Application health status (1 = healthy, 0 = unhealthy)",
		},
		[]string{"service"},
	)
)

// Application struct
type App struct {
	config *Config
	router *mux.Router
}

// Load secrets from AWS Secrets Manager
func loadSecrets(secretARN string) (*Secrets, error) {
	if secretARN == "" {
		// Return default secrets for local development
		return &Secrets{
			SuperSecretToken: "dev-token-12345",
			DatabaseURL:      "postgresql://dev:dev@localhost:5432/podinfo",
			APIKey:          "dev-api-key",
		}, nil
	}

	sess, err := session.NewSession(&aws.Config{
		Region: aws.String("us-west-2"),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create AWS session: %v", err)
	}

	svc := secretsmanager.New(sess)
	result, err := svc.GetSecretValue(&secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretARN),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get secret: %v", err)
	}

	var secrets Secrets
	if err := json.Unmarshal([]byte(*result.SecretString), &secrets); err != nil {
		return nil, fmt.Errorf("failed to unmarshal secret: %v", err)
	}

	return &secrets, nil
}

// Correlation ID middleware
func correlationIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		correlationID := r.Header.Get("X-Correlation-ID")
		if correlationID == "" {
			correlationID = uuid.New().String()
		}
		
		// Add correlation ID to response headers
		w.Header().Set("X-Correlation-ID", correlationID)
		
		// Add to request context
		ctx := context.WithValue(r.Context(), "correlationID", correlationID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// Initialize application
func NewApp() *App {
	config := &Config{
		Port:        getEnv("PORT", "8080"),
		Environment: getEnv("ENVIRONMENT", "dev"),
		LogLevel:    getEnv("LOG_LEVEL", "info"),
		Version:     getEnv("VERSION", "1.0.0"),
		BuildTime:   getEnv("BUILD_TIME", time.Now().Format(time.RFC3339)),
		Commit:      getEnv("COMMIT", "unknown"),
		SecretARN:   getEnv("SECRET_ARN", ""),
	}

	// Load secrets
	loadedSecrets, err := loadSecrets(config.SecretARN)
	if err != nil {
		log.Printf("Warning: Failed to load secrets: %v", err)
		loadedSecrets = &Secrets{
			SuperSecretToken: "fallback-token",
			DatabaseURL:      "postgresql://fallback:fallback@localhost:5432/podinfo",
			APIKey:          "fallback-api-key",
		}
	}
	
	// Set global secrets variable
	secrets = *loadedSecrets

	// Register Prometheus metrics
	prometheus.MustRegister(httpRequestsTotal)
	prometheus.MustRegister(httpRequestDuration)
	prometheus.MustRegister(applicationHealth)

	app := &App{
		config: config,
		router: mux.NewRouter(),
	}

	app.setupRoutes()
	return app
}

// Setup routes
func (a *App) setupRoutes() {
	// Middleware
	a.router.Use(correlationIDMiddleware)
	a.router.Use(a.loggingMiddleware)
	a.router.Use(a.metricsMiddleware)
	a.router.Use(a.corsMiddleware)

	// Health endpoints
	a.router.HandleFunc("/healthz", a.healthCheck).Methods("GET")
	a.router.HandleFunc("/readyz", a.readinessCheck).Methods("GET")

	// API endpoints
	a.router.HandleFunc("/", a.homeHandler).Methods("GET")
	a.router.HandleFunc("/version", a.versionHandler).Methods("GET")
	a.router.HandleFunc("/info", a.infoHandler).Methods("GET")
	a.router.HandleFunc("/metrics", a.metricsHandler).Methods("GET")

	// Simulate some business logic
	a.router.HandleFunc("/api/data", a.dataHandler).Methods("GET")
	a.router.HandleFunc("/api/secret", a.secretHandler).Methods("GET")

	// Prometheus metrics endpoint
	a.router.Path("/metrics").Handler(promhttp.Handler())
}

// Middleware functions
func (a *App) loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		duration := time.Since(start)

		log.Printf("[%s] %s %s %s %v",
			r.RemoteAddr, r.Method, r.URL.Path, r.Proto, duration)
	})
}

func (a *App) metricsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		duration := time.Since(start)

		httpRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration.Seconds())
	})
}

func (a *App) corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// Handler functions
func (a *App) homeHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"message":     "Welcome to Podinfo",
		"version":     a.config.Version,
		"environment": a.config.Environment,
		"timestamp":   time.Now().Format(time.RFC3339),
		"request_id":  generateRequestID(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (a *App) versionHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]string{
		"version":   a.config.Version,
		"buildTime": a.config.BuildTime,
		"commit":    a.config.Commit,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (a *App) infoHandler(w http.ResponseWriter, r *http.Request) {
	response := map[string]interface{}{
		"version":     a.config.Version,
		"environment": a.config.Environment,
		"buildTime":   a.config.BuildTime,
		"commit":      a.config.Commit,
		"port":        a.config.Port,
		"logLevel":    a.config.LogLevel,
		"uptime":      getUptime(),
		"request_id":  generateRequestID(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (a *App) healthCheck(w http.ResponseWriter, r *http.Request) {
	// Simulate health check logic
	healthy := true

	// Check if we can connect to external services
	// In a real application, this would check database, cache, etc.

	if healthy {
		applicationHealth.WithLabelValues("podinfo").Set(1)
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{
			"status":    "healthy",
			"timestamp": time.Now().Format(time.RFC3339),
		})
	} else {
		applicationHealth.WithLabelValues("podinfo").Set(0)
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status":    "unhealthy",
			"timestamp": time.Now().Format(time.RFC3339),
		})
	}
}

func (a *App) readinessCheck(w http.ResponseWriter, r *http.Request) {
	// Simulate readiness check
	ready := true

	// Check if the application is ready to serve traffic
	// This could check database connections, external dependencies, etc.

	if ready {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{
			"status":    "ready",
			"timestamp": time.Now().Format(time.RFC3339),
		})
	} else {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status":    "not ready",
			"timestamp": time.Now().Format(time.RFC3339),
		})
	}
}

func (a *App) dataHandler(w http.ResponseWriter, r *http.Request) {
	// Simulate some business logic
	data := map[string]interface{}{
		"id":          generateRequestID(),
		"message":     "Sample data from Podinfo",
		"timestamp":   time.Now().Format(time.RFC3339),
		"environment": a.config.Environment,
		"version":     a.config.Version,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func (a *App) secretHandler(w http.ResponseWriter, r *http.Request) {
	// Get correlation ID from context
	correlationID := r.Context().Value("correlationID")
	if correlationID == nil {
		correlationID = "unknown"
	}

	// Return secret status without exposing actual values
	secret := map[string]interface{}{
		"message":        "Secret data retrieved successfully",
		"timestamp":      time.Now().Format(time.RFC3339),
		"correlation_id": correlationID,
		"secret_status": map[string]interface{}{
			"super_secret_token_loaded": secrets.SuperSecretToken != "",
			"database_url_loaded":      secrets.DatabaseURL != "",
			"api_key_loaded":          secrets.APIKey != "",
		},
		"environment": a.config.Environment,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(secret)
}

func (a *App) metricsHandler(w http.ResponseWriter, r *http.Request) {
	// Custom metrics endpoint
	metrics := map[string]interface{}{
		"application": "podinfo",
		"version":     a.config.Version,
		"environment": a.config.Environment,
		"uptime":      getUptime(),
		"timestamp":   time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(metrics)
}

// Utility functions
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func generateRequestID() string {
	n, _ := rand.Int(rand.Reader, big.NewInt(1000000))
	return fmt.Sprintf("req-%d", n.Int64())
}

func getUptime() string {
	// In a real application, this would track actual uptime
	return "1h23m45s"
}

// Start the application
func (a *App) Start() {
	log.Printf("Starting Podinfo server on port %s", a.config.Port)
	log.Printf("Environment: %s", a.config.Environment)
	log.Printf("Version: %s", a.config.Version)

	server := &http.Server{
		Addr:         ":" + a.config.Port,
		Handler:      a.router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	log.Fatal(server.ListenAndServe())
}

// Main function
func main() {
	app := NewApp()
	app.Start()
}
