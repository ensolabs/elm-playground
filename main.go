package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

const (
	elmJsonFile = "elm.json"
	rootElmJson = "./" + elmJsonFile
	appUrl      = "https://elm-playground.onrender.com"
)

var (
	elmBin              = "elm"
	workingDir          string
	maxConcurrentBuilds = 1 // Default to 2 concurrent compilations
	buildSemaphore      chan struct{}
)

func main() {
	// Set GOMEMLIMIT for Go 1.19+ memory management
	if os.Getenv("GOMEMLIMIT") == "" {
		if err := os.Setenv("GOMEMLIMIT", "350MiB"); err != nil {
			log.Printf("[warn] failed to set GOMEMLIMIT: %v", err)
		}
	}
	// Set aggressive GC target for memory-constrained environment
	debug.SetGCPercent(10) // More aggressive than default 100
	// Configure max concurrent builds from environment
	if maxBuildsStr := os.Getenv("MAX_CONCURRENT_BUILDS"); maxBuildsStr != "" {
		if maxBuilds, err := strconv.Atoi(maxBuildsStr); err == nil && maxBuilds > 0 {
			maxConcurrentBuilds = maxBuilds
		}
	}
	// Initialize semaphore for concurrent builds
	buildSemaphore = make(chan struct{}, maxConcurrentBuilds)
	fmt.Printf("[info] max concurrent builds: %d", maxConcurrentBuilds)
	fmt.Printf("[info] GOMEMLIMIT: %s", os.Getenv("GOMEMLIMIT"))
	envElmBin, ok := os.LookupEnv("ELM_BIN")
	if ok {
		elmBin, _ = filepath.Abs(envElmBin)
	}

	workingDir, _ = filepath.Abs("./")

	app := fiber.New(fiber.Config{
		// Reduce memory usage
		ReduceMemoryUsage: true,
		Prefork:           false,
		CaseSensitive:     false,
		StrictRouting:     false,
		ServerHeader:      "",
		// Limit body size to 512KB to reduce memory pressure
		BodyLimit: 512 * 1024,
	})

	app.Post("/compile", compileHandler)
	app.Get("/health", handleHealthCheck)
	app.Static("/", "./static")

	go keepAlive()
	printMemStats()

	fmt.Println("Server listening on http://localhost:8080")
	if err := app.Listen(":8080"); err != nil {
		printMemStats()
		log.Fatalf("[fatal] failed to start server: %v\n", err)
	}
}

func printMemStats() string {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	stats := fmt.Sprintf("Alloc: %d KB, Sys: %d KB, NumGC: %d",
		m.Alloc/1024, m.Sys/1024, m.NumGC)
	fmt.Printf("[info] Memory - %s", stats)

	return stats
}

func logMemoryPressure() {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	allocMB := m.Alloc / 1024 / 1024
	if allocMB > 200 { // Warn if over 200MB
		log.Printf("[warn] High memory usage: %d MB allocated", allocMB)
		runtime.GC() // Force GC if memory is high
		debug.FreeOSMemory()
	}
}

func handleHealthCheck(c *fiber.Ctx) error {
	stats := printMemStats()
	activeBuilds := len(buildSemaphore)
	status := fmt.Sprintf("OK - Active builds: %d/%d; %s", activeBuilds, maxConcurrentBuilds, stats)
	return c.SendString(status)
}

func compileHandler(c *fiber.Ctx) error {
	elmCode := c.Body()
	if len(elmCode) == 0 {
		return c.Status(400).SendString("No Elm code provided")
	}

	// Acquire semaphore slot (blocks if all slots are taken)
	buildSemaphore <- struct{}{}
	defer func() { <-buildSemaphore }() // Release slot when done

	fmt.Printf("[info] starting compilation (active: %d/%d)", len(buildSemaphore), maxConcurrentBuilds)

	// Monitor memory before compilation
	logMemoryPressure()
	// Force garbage collection before compilation
	runtime.GC()
	debug.FreeOSMemory()

	tempDir, err := os.MkdirTemp(workingDir, "elm-compile-*")
	if err != nil {
		return c.Status(500).SendString("Failed to create tmp dir")
	}

	// Ensure cleanup
	defer func() {
		if cleanupErr := os.RemoveAll(tempDir); cleanupErr != nil {
			log.Printf("[warn] failed to remove temp dir %s: %v\n", tempDir, cleanupErr)
		}
		// Force GC and return memory to OS
		runtime.GC()
		debug.FreeOSMemory()
	}()

	mainSrcFile := filepath.Join(tempDir, "Main.elm")
	if err := os.WriteFile(mainSrcFile, elmCode, 0644); err != nil {
		log.Printf("[error] failed to write Elm file: %v\n", err)
		return c.Status(500).SendString("Failed to write Elm file")
	}

	fmt.Println("[info] initiating elm make")

	targetOutputPath := filepath.Join(tempDir, "index.html")
	cmd := exec.Command(elmBin, "make", mainSrcFile, fmt.Sprintf("--output=%s", targetOutputPath))
	cmd.Dir = tempDir
	// Set memory limits for the Elm subprocess
	cmd.Env = append(os.Environ(),
		"LANG=C",   // Reduce locale memory overhead
		"LC_ALL=C", // Reduce locale memory overhead
	)

	output, err := cmd.CombinedOutput()
	fmt.Printf("[info] elm make output length: %d bytes", len(output))

	if err != nil {
		log.Printf("[warn] Elm compilation failed\n%v\n\n", err)
		outStr := string(output)
		marker := "Compiling ..."
		if idx := strings.Index(outStr, marker); idx >= 0 {
			start := idx + len(marker)
			if start < len(outStr) {
				outStr = strings.TrimLeft(outStr[start:], "\r\n\t ")
			} else {
				outStr = ""
			}
		}
		return c.Status(400).SendString(outStr)
	}

	// Check file size before reading to avoid large allocations
	fileInfo, err := os.Stat(targetOutputPath)
	if err != nil {
		log.Printf("[error] failed to stat compiled output: %v\n", err)
		return c.Status(500).SendString("Failed to read compiled output")
	}
	// Limit compiled output size to prevent memory issues
	const maxFileSize = 5 * 1024 * 1024 // 5MB limit
	if fileInfo.Size() > maxFileSize {
		log.Printf("[error] compiled output too large: %d bytes (max: %d)", fileInfo.Size(), maxFileSize)
		return c.Status(413).SendString("Compiled output too large")
	}

	// Read the compiled output
	compiledData, err := os.ReadFile(targetOutputPath)
	if err != nil {
		log.Printf("[error] failed to read compiled output: %v\n", err)
		return c.Status(500).SendString("Failed to read compiled output")
	}

	fmt.Printf("[info] successfully compiled Elm to HTML (%d bytes)", len(compiledData))
	c.Type("text/html")
	return c.Send(compiledData)
}

func keepAlive() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	for range ticker.C {
		resp, err := client.Get(appUrl + "/health")
		if err != nil {
			log.Printf("[warn] keep-alive request failed: %v", err)
		} else {
			if closeErr := resp.Body.Close(); closeErr != nil {
				log.Printf("[warn] failed to close response body: %v", closeErr)
			}
		}
	}
}
