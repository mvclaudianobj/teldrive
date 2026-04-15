package main

import (
	"bytes"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"

	"github.com/fsnotify/fsnotify"
	"github.com/spf13/cobra"
)

var (
	watchDir  string
	serverURL string
	jwtToken  string
)

func main() {
	var rootCmd = &cobra.Command{
		Use:   "sync-agent",
		Short: "Marks Drive Sync Agent",
		Long:  "Agent to sync a directory with Marks Drive",
		Run:   runSync,
	}

	rootCmd.Flags().StringVar(&watchDir, "dir", ".", "Directory to watch")
	rootCmd.Flags().StringVar(&serverURL, "url", "https://drive.marks.com.br", "Marks Drive server URL")
	rootCmd.Flags().StringVar(&jwtToken, "token", "", "JWT token for authentication")

	if err := rootCmd.Execute(); err != nil {
		log.Fatal(err)
	}
}

func runSync(cmd *cobra.Command, args []string) {
	if jwtToken == "" {
		log.Fatal("JWT token is required")
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer watcher.Close()

	err = filepath.Walk(watchDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return watcher.Add(path)
		}
		return nil
	})
	if err != nil {
		log.Fatal(err)
	}

	log.Printf("Watching directory: %s", watchDir)

	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			if event.Has(fsnotify.Write) || event.Has(fsnotify.Create) {
				if !isDir(event.Name) {
					log.Printf("File changed/created: %s", event.Name)
					uploadFile(event.Name)
				}
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Println("error:", err)
		}
	}
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}

func uploadFile(filePath string) {
	file, err := os.Open(filePath)
	if err != nil {
		log.Printf("Failed to open file %s: %v", filePath, err)
		return
	}
	defer file.Close()

	var b bytes.Buffer
	w := multipart.NewWriter(&b)

	// Add file
	fw, err := w.CreateFormFile("file", filepath.Base(filePath))
	if err != nil {
		log.Printf("Failed to create form file: %v", err)
		return
	}
	if _, err = io.Copy(fw, file); err != nil {
		log.Printf("Failed to copy file: %v", err)
		return
	}

	w.Close()

	req, err := http.NewRequest("POST", serverURL+"/api/uploads", &b)
	if err != nil {
		log.Printf("Failed to create request: %v", err)
		return
	}
	req.Header.Set("Content-Type", w.FormDataContentType())
	req.Header.Set("Authorization", "Bearer "+jwtToken)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Failed to upload: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("Upload failed with status %d: %s", resp.StatusCode, string(body))
		return
	}

	log.Printf("Successfully uploaded %s", filePath)
}
