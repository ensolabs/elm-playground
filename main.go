package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

const (
	elmJsonFile    = "elm.json"
	rootElmJson    = "./" + elmJsonFile
	exercisesDir   = "./exercises"
	exercisePrefix = "Exercise"
	appUrl         = "https://elm-playground.onrender.com"
)

var elmBin = "elm"

func main() {
	envElmBin, ok := os.LookupEnv("ELM_BIN")
	if ok {
		elmBin, _ = filepath.Abs(envElmBin)
	}

	// Pre-warm Elm dependencies to avoid downloads on first compile
	var err error
	warmDir, err := prewarmElm()
	if err != nil {
		log.Fatalf("[fatal] warm-up failed: %v\n", err)
	}

	// Clean up warm directory on exit
	defer func() {
		if warmDir != "" {
			os.RemoveAll(warmDir)
		}
	}()

	// Force garbage collection and print memory stats
	runtime.GC()
	printMemStats()

	app := fiber.New(fiber.Config{
		// Reduce memory usage
		Prefork:       false,
		CaseSensitive: false,
		StrictRouting: false,
		ServerHeader:  "",
		// Limit body size to 1MB
		BodyLimit: 1024 * 1024,
	})

	app.Post("/compile", compileHandler(warmDir))
	app.Get("/health", handleHealthCheck)
	app.Get("/exercises", handleListExercises)
	app.Get("/:id", handleGetExercise)
	app.Static("/", "./static")

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Only start keep-alive if we're on the actual hosting platform
	if strings.Contains(appUrl, "onrender.com") {
		keepAlive(ctx)
	}

	fmt.Println("Server listening on http://localhost:8080")
	if err := app.Listen(":8080"); err != nil {
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
	return c.SendString("OK")
}

func handleListExercises(c *fiber.Ctx) error {
	exercises, err := getExercises()
	if err != nil {
		log.Printf("[error] failed to list exercises: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Failed to list exercises")
	}
	return c.JSON(exercises)
}

func handleGetExercise(c *fiber.Ctx) error {
	id := c.Params("id")

	exercises, err := getExercises()
	if err != nil {
		log.Printf("[error] failed to list exercises: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Failed to list exercises")
	}

	var filename string
	for _, exercise := range exercises {
		if strings.HasPrefix(exercise.ID, id) {
			filename = exercise.Filename
			break
		}
	}

	if filename == "" {
		return c.Status(http.StatusNotFound).SendString("Exercise not found")
	}

	content, err := os.ReadFile(filepath.Join(exercisesDir, filename))
	if err != nil {
		log.Printf("[error] failed to read exercise file: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Failed to read exercise file")
	}

	return c.SendString(string(content))
}

type Exercise struct {
	ID       string `json:"id"`
	Title    string `json:"title"`
	Filename string `json:"filename"`
}

func getExercises() ([]Exercise, error) {
	entries, err := os.ReadDir(exercisesDir)
	if err != nil {
		return nil, err
	}

	exercises := []Exercise{}
	re := regexp.MustCompile(`Exercise(\d+)(.*)\.elm`)

	for _, entry := range entries {
		if !entry.IsDir() && strings.HasPrefix(entry.Name(), exercisePrefix) {
			matches := re.FindStringSubmatch(entry.Name())
			if len(matches) >= 3 {
				id := matches[1]
				title := matches[2]
				exercises = append(exercises, Exercise{
					ID:       id,
					Title:    title,
					Filename: entry.Name(),
				})
			}
		}
	}

	return exercises, nil
}

func compileHandler(warmDir string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Force garbage collection before compilation
		runtime.GC()

		elmCode := c.Body()
		if len(elmCode) == 0 {
			return c.Status(400).SendString("No Elm code provided")
		}

		// Create temp directory with more specific prefix
		tempDir, err := os.MkdirTemp("", "elm-compile-*")
		if err != nil {
			log.Printf("[error] could not create temp dir: %v\n", err)
			return c.Status(http.StatusInternalServerError).SendString("Could not create temp dir")
		}

		// Ensure cleanup happens no matter what
		defer func() {
			if cleanupErr := os.RemoveAll(tempDir); cleanupErr != nil {
				log.Printf("[warn] failed to remove temp dir %s: %v\n", tempDir, cleanupErr)
			}
			// Force GC after cleanup
			runtime.GC()
		}()

		srcDir := filepath.Join(tempDir, "src")
		if err := os.MkdirAll(srcDir, 0755); err != nil {
			log.Printf("[error] could not create src dir: %v\n", err)
			return c.Status(http.StatusInternalServerError).SendString("Could not create src dir")
		}

		// Use elm.json from warm-up directory
		elmJsonSource := filepath.Join(warmDir, elmJsonFile)
		if _, statErr := os.Stat(elmJsonSource); statErr != nil {
			log.Printf("[error] warm-up elm.json missing: %v\n", statErr)
			return c.Status(http.StatusInternalServerError).SendString("Warm-up elm.json not found")
		}

		// Copy instead of symlink to avoid issues
		if err := copyFile(elmJsonSource, filepath.Join(tempDir, elmJsonFile)); err != nil {
			log.Printf("[error] could not copy elm.json: %v\n", err)
			return c.Status(http.StatusInternalServerError).SendString("Could not copy elm.json")
		}

		// Link compiled artifacts from warm-up (this is the big memory saver)
		warmElmStuff := filepath.Join(warmDir, "elm-stuff")
		if _, statErr := os.Stat(warmElmStuff); statErr != nil {
			log.Printf("[error] warm-up elm-stuff missing: %v\n", statErr)
			return c.Status(http.StatusInternalServerError).SendString("Warm-up elm-stuff not found")
		}
		absElmStuff, _ := filepath.Abs(warmElmStuff)
		if err := os.Symlink(absElmStuff, filepath.Join(tempDir, "elm-stuff")); err != nil {
			log.Printf("[error] could not symlink elm-stuff: %v\n", err)
			return c.Status(http.StatusInternalServerError).SendString("Could not symlink elm-stuff")
		}

		mainSrcFile := filepath.Join(srcDir, "Main.elm")
		if err := os.WriteFile(mainSrcFile, elmCode, 0644); err != nil {
			log.Printf("[error] failed to write Elm file: %v\n", err)
			return c.Status(500).SendString("Failed to write Elm file")
		}

		cmd := exec.Command(elmBin, "make", "src/Main.elm", "--output=main.js")
		cmd.Dir = tempDir
		output, err := cmd.CombinedOutput()
		if err != nil {
			log.Printf("[warn] Elm compilation failed\n%v", err)
			outStr := string(output)
			marker := "Dependencies ready!"
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

		compiledJsPath := filepath.Join(tempDir, "main.js")
		compiledJs, err := os.ReadFile(compiledJsPath)
		if err != nil {
			log.Printf("[error] failed to read compiled JS: %v\n", err)
			return c.Status(500).SendString("Failed to read compiled JS")
		}

		log.Printf("[info] successfully compiled Elm to JS (%d bytes)\n", len(compiledJs))
		c.Type("application/javascript")
		return c.Send(compiledJs)
	}
}

// copyFile copies a file from src to dst
func copyFile(src, dst string) error {
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0644)
}

func keepAlive(ctx context.Context) {
	ticker := time.NewTicker(5 * time.Minute) // Reduced frequency
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

// prewarmElm performs a minimal Elm build at startup and returns the warm-up directory
func prewarmElm() (string, error) {
	tempDir, err := os.MkdirTemp("", "elm-warmup-*")
	if err != nil {
		return "", fmt.Errorf("create warm-up temp dir: %w", err)
	}

	srcDir := filepath.Join(tempDir, "src")
	if err := os.MkdirAll(srcDir, 0755); err != nil {
		os.RemoveAll(tempDir)
		return "", fmt.Errorf("create warm-up src dir: %w", err)
	}

	// Copy the root elm.json instead of symlinking
	if err := copyFile(rootElmJson, filepath.Join(tempDir, elmJsonFile)); err != nil {
		os.RemoveAll(tempDir)
		return "", fmt.Errorf("copy elm.json: %w", err)
	}

	// Write a minimal Elm module
	mainSrcFile := filepath.Join(srcDir, "Main.elm")
	warmupElm := []byte("module Main exposing (main)\n\nimport Html exposing (text)\n\nmain = text \"warmup\"\n")
	if err := os.WriteFile(mainSrcFile, warmupElm, 0644); err != nil {
		os.RemoveAll(tempDir)
		return "", fmt.Errorf("write warm-up Elm file: %w", err)
	}

	// Run elm make to trigger dependency download/caching
	cmd := exec.Command(elmBin, "make", "src/Main.elm", "--output=/dev/null")
	cmd.Dir = tempDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		os.RemoveAll(tempDir)
		return "", fmt.Errorf("elm make failed: %w\n%s", err, string(output))
	}

	fmt.Printf("[info] warm-up: Elm dependencies are ready\n")
	return tempDir, nil
}
