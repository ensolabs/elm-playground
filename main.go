package main

import (
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/gofiber/fiber/v2"
)

const (
	elmJsonFile = "elm.json"
	rootElmJson = "./" + elmJsonFile
)

func main() {
	app := fiber.New()

	app.Post("/compile", handleCompile)
	app.Static("/", "./static")

	log.Println("Server listening on http://localhost:8080")
	if err := app.Listen(":8080"); err != nil {
		log.Fatalf("[fatal] failed to start server: %v\n", err)
	}
}

func handleCompile(c *fiber.Ctx) error {
	elmCode := c.Body()

	tempDir, err := os.MkdirTemp("tmp", "elm-playground-*")
	if err != nil {
		log.Printf("[error] could not create temp dir: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Could not create temp dir")
	}
	defer os.RemoveAll(tempDir)

	srcDir := filepath.Join(tempDir, "src")
	if err := os.MkdirAll(srcDir, 0755); err != nil {
		log.Printf("[error] could not create src dir: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Could not create src dir")
	}

	symlinkTarget := filepath.Join(tempDir, elmJsonFile)
	if err := os.Symlink(rootElmJson, symlinkTarget); err != nil {
		log.Printf("[error] could not symlink elm.json: %v\n", err)
		return c.Status(http.StatusInternalServerError).SendString("Could not symlink elm.json")
	}

	mainSrcFile := filepath.Join(srcDir, "Main.elm")
	if err := os.WriteFile(mainSrcFile, elmCode, 0644); err != nil {
		log.Printf("[error] failed to write Elm file: %v\n", err)
		return c.Status(500).SendString("Failed to write Elm file")
	}

	cmd := exec.Command("elm", "make", "src/Main.elm", "--output=main.js")
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
