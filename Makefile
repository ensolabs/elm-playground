# Default target - builds both frontend and backend
.PHONY: all build-frontend build-backend clean

all: build-frontend build-backend

build-frontend:
	@echo "Building frontend..."
	./elm make src/Main.elm --optimize --output="static/elm.js"

build-backend:
	@echo "Building backend..."
	CGO_ENABLED=0 go build -tags netgo -ldflags '-s -w' -o app

clean:
	@echo "Cleaning build artifacts..."
	rm static/elm.js
	rm app
	rm -rf elm-compile-*
