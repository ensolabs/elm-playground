package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

const (
	elmJsonFile = "elm.json"
	rootElmJson = "./" + elmJsonFile
	appUrl      = "https://elm-playground.onrender.com"
)

type CompileRequest struct {
	elmCode    []byte
	resultChan chan CompileResult
}

type CompileResult struct {
	data        []byte
	contentType string
	err         error
}

var (
	elmBin       = "elm"
	workingDir   string
	compileQueue chan CompileRequest
	queueSize    = 5 // Allow up to 5 queued requests
)

func main() {
	// Set aggressive GC target for memory-constrained environment
	debug.SetGCPercent(20) // Default is 100, lower = more frequent GC
	envElmBin, ok := os.LookupEnv("ELM_BIN")
	if ok {
		elmBin, _ = filepath.Abs(envElmBin)
	}

	workingDir, _ = filepath.Abs("./")

	// Initialize the compile queue
	compileQueue = make(chan CompileRequest, queueSize)
	// Start the compilation worker
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go compileWorker(ctx)

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

	keepAlive(ctx)
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
	stats := fmt.Sprintf("%d KB, Sys: %d KB\n",
		m.Alloc/1024, m.Sys/1024)
	fmt.Print("[info] Memory - Alloc: " + stats)

	return stats
}

func handleHealthCheck(c *fiber.Ctx) error {
	stats := printMemStats()
	queueLen := len(compileQueue)
	status := fmt.Sprintf("OK - Queue: %d/%d; %s", queueLen, queueSize, stats)
	return c.SendString(status)
}

func compileHandler(c *fiber.Ctx) error {
	elmCode := c.Body()
	if len(elmCode) == 0 {
		return c.Status(400).SendString("No Elm code provided")
	}

	// Create a result channel for this request
	resultChan := make(chan CompileResult, 1)
	// Create compile request
	request := CompileRequest{
		elmCode:    elmCode,
		resultChan: resultChan,
	}

	// Try to queue the request (non-blocking)
	select {
	case compileQueue <- request:
		// Request queued successfully
		queueLen := len(compileQueue)
		if queueLen > 0 {
			log.Printf("[info] compilation queued (queue size: %d)", queueLen+1) // +1 for current processing
		}
	default:
		// Queue is full
		return c.Status(503).SendString("Compilation queue is full, please try again later")
	}

	// Wait for result with timeout
	select {
	case result := <-resultChan:
		if result.err != nil {
			if strings.Contains(result.err.Error(), "compilation_failed:") {
				errorMsg := strings.TrimPrefix(result.err.Error(), "compilation_failed:")
				return c.Status(400).SendString(errorMsg)
			}
			log.Printf("[error] compilation error: %v", result.err)
			return c.Status(500).SendString("Internal compilation error")
		}
		c.Type(result.contentType)
		return c.Send(result.data)
	case <-time.After(60 * time.Second): // 60 second timeout
		return c.Status(408).SendString("Compilation timeout")
	}
}

func compileWorker(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case request := <-compileQueue:
			result := processCompileRequest(request.elmCode)
			// Send result back (non-blocking)
			select {
			case request.resultChan <- result:
			case <-time.After(10 * time.Second):
				log.Printf("[warn] failed to send compilation result (timeout)")
			}
		}
	}
}

func processCompileRequest(elmCode []byte) CompileResult {
	// Force garbage collection before compilation
	runtime.GC()
	debug.FreeOSMemory()

	tempDir, err := os.MkdirTemp(workingDir, "elm-compile-*")
	if err != nil {
		return CompileResult{err: fmt.Errorf("failed to create tmp dir: %v", err)}
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
		return CompileResult{err: fmt.Errorf("failed to write Elm file: %v", err)}
	}

	fmt.Println("[info] initiating elm make")

	targetOutputPath := filepath.Join(tempDir, "index.html")
	cmd := exec.Command(elmBin, "make", mainSrcFile, fmt.Sprintf("--output=%s", targetOutputPath))
	cmd.Dir = tempDir

	output, err := cmd.CombinedOutput()
	fmt.Printf("[info] elm make output:\n%s\n", output)

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
		return CompileResult{err: fmt.Errorf("compilation_failed:%s", outStr)}
	}

	// Read the compiled output into memory
	compiledData, err := os.ReadFile(targetOutputPath)
	if err != nil {
		log.Printf("[error] failed to read compiled output: %v\n", err)
		return CompileResult{err: fmt.Errorf("failed to read compiled output: %v", err)}
	}

	fmt.Printf("[info] successfully compiled Elm to HTML (%d bytes)\n", len(compiledData))
	return CompileResult{
		data:        compiledData,
		contentType: "text/html",
		err:         nil,
	}
}

func keepAlive(ctx context.Context) {
	ticker := time.NewTicker(1 * time.Minute) // Reduced frequency
	defer ticker.Stop()

	client := &http.Client{
		Timeout: 10 * time.Second,
	}

	go func() {
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
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
	}()
}
