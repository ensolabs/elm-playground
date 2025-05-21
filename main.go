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
		elmBin = envElmBin
	}

	app := fiber.New()

	app.Post("/compile", handleCompile)
	app.Get("/health", handleHealthCheck)
	app.Get("/exercises", handleListExercises)
	app.Get("/:id", handleGetExercise)
	app.Static("/", "./static")

	ctx := context.Background()
	keepAlive(ctx)

	fmt.Println("Server listening on http://localhost:8080")
	if err := app.Listen(":8080"); err != nil {
		log.Fatalf("[fatal] failed to start server: %v\n", err)
	}
}

func handleHealthCheck(c *fiber.Ctx) error {
	return c.SendString("OK")
}

// handleListExercises returns a list of all exercise files
func handleListExercises(c *fiber.Ctx) error {
	exercises, err := getExercises()
	if err != nil {
		log.Printf("[error] failed to list exercises: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Failed to list exercises")
	}
	return c.JSON(exercises)
}

// handleGetExercise returns the content of a specific exercise by ID
func handleGetExercise(c *fiber.Ctx) error {
	id := c.Params("id")

	// Find the exercise file that matches the ID
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

// Exercise represents an exercise file
type Exercise struct {
	ID       string `json:"id"`
	Title    string `json:"title"`
	Filename string `json:"filename"`
}

// getExercises returns a list of all exercise files
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

// handleCompile compiles the Elm code in POST body to JS
func handleCompile(c *fiber.Ctx) error {
	elmCode := c.Body()

	tempDir, err := os.MkdirTemp("temp", "elm-playground-*")
	if err != nil {
		log.Printf("[error] could not create temp dir: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Could not create temp dir")
	}
	defer func() {
		if err := os.RemoveAll(tempDir); err != nil {
			log.Printf("[warn] failed to remove temp dir %s: %v\n", tempDir, err)
		}
	}()

	srcDir := filepath.Join(tempDir, "src")
	if err := os.MkdirAll(srcDir, 0755); err != nil {
		log.Printf("[error] could not create src dir: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Could not create src dir")
	}

	absRootElmJson, err := filepath.Abs(rootElmJson)
	if err != nil {
		log.Printf("[error] could not get absolute path to elm.json: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Could not resolve elm.json path")
	}
	if err := os.Symlink(absRootElmJson, filepath.Join(tempDir, elmJsonFile)); err != nil {
		log.Printf("[error] could not symlink elm.json: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Could not symlink elm.json")
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
		log.Printf("[warn] Elm compilation failed\n")
		return c.Status(400).SendString(string(output))
	}

	compiledJsPath := filepath.Join(tempDir, "main.js")
	compiledJs, err := os.ReadFile(compiledJsPath)
	if err != nil {
		log.Printf("[error] failed to read compiled JS: %v\n", err)
		return c.Status(500).SendString("Failed to read compiled JS")
	}

	log.Printf("[info] successfully compiled Elm to JS\n")
	c.Type("application/javascript")
	return c.Send(compiledJs)
}

func keepAlive(ctx context.Context) {
	ticker := time.NewTicker(time.Minute)

	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				http.Get(appUrl + "/health")
			}
		}
	}()
}
