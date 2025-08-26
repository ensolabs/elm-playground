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
	elmBin     = "elm"
	workingDir string
)

func main() {
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
		// Limit body size to 1MB
		BodyLimit: 1024 * 1024,
	})

	app.Post("/compile", compileHandler)
	app.Get("/health", handleHealthCheck)
	app.Static("/", "./static")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	keepAlive(ctx)
	printMemStats()

	fmt.Println("Server listening on http://localhost:8080")
	if err := app.Listen(":8080"); err != nil {
		printMemStats()
		log.Fatalf("[fatal] failed to start server: %v\n", err)
	}
}

func printMemStats() {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	fmt.Printf("[info] Memory - Alloc: %d KB, Sys: %d KB\n",
		m.Alloc/1024, m.Sys/1024)
}

func handleHealthCheck(c *fiber.Ctx) error {
	printMemStats()
	return c.SendString("OK")
}

func compileHandler(c *fiber.Ctx) error {
	// Force garbage collection before compilation
	runtime.GC()

	elmCode := c.Body()
	if len(elmCode) == 0 {
		return c.Status(400).SendString("No Elm code provided")
	}

	tempDir, err := os.MkdirTemp(workingDir, "elm-compile-*")
	if err != nil {
		return c.Status(500).SendString("Failed to create tmp dir")
	}

	// Ensure cleanup, both garbage collection and file deletion
	defer func() {
		if cleanupErr := os.RemoveAll(tempDir); cleanupErr != nil {
			log.Printf("[warn] failed to remove temp dir %s: %v\n", tempDir, cleanupErr)
		}
		// Force GC after cleanup
		runtime.GC()
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
		return c.Status(400).SendString(outStr)
	}

	compiledCode, err := os.ReadFile(targetOutputPath)
	if err != nil {
		log.Printf("[error] failed to read compiled JS: %v\n", err)
		return c.Status(500).SendString("Failed to read compiled JS")
	}

	fmt.Printf("[info] successfully compiled Elm to JS (%d bytes)\n", len(compiledCode))
	c.Type("application/javascript")
	return c.Send(compiledCode)
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
					resp.Body.Close()
				}
			}
		}
	}()
}
