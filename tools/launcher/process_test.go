package main

import (
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
	"time"
)

// Exercise the actual executable and Linux wrapper, without a Godot installation.
func TestPortableProcess(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "Полная игра с пробелами")
	if err := os.MkdirAll(filepath.Join(dir, "web"), 0755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"index.html", "index.js", "index.wasm", "index.pck"} {
		if err := os.WriteFile(filepath.Join(dir, "web", name), []byte("packaged-game"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	goName, exeName := "go", "SkyJump"
	if runtime.GOOS == "windows" {
		goName += ".exe"
		exeName += ".exe"
	}
	bin := filepath.Join(dir, exeName)
	build := exec.Command(filepath.Join(runtime.GOROOT(), "bin", goName), "build", "-o", bin, ".")
	if output, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build: %v\n%s", err, output)
	}
	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	address := listener.Addr().String()
	_, port, _ := net.SplitHostPort(address)
	listener.Close()
	command := exec.Command(bin, "-no-browser", "-port", port)
	if runtime.GOOS == "linux" {
		wrapper, err := os.ReadFile("play-skyjump.sh")
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "play-skyjump.sh"), wrapper, 0644); err != nil {
			t.Fatal(err)
		}
		if err := os.Chmod(bin, 0644); err != nil {
			t.Fatal(err)
		}
		command = exec.Command("bash", filepath.Join(dir, "play-skyjump.sh"), "-no-browser", "-port", port)
	}
	command.Dir = t.TempDir() // Not the game directory.
	if err := command.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { command.Process.Kill(); command.Wait() })
	client := &http.Client{Timeout: time.Second}
	url := "http://" + address + "/"
	ready := false
	for attempt := 0; attempt < 50; attempt++ {
		response, err := client.Get(url)
		if err == nil {
			body, _ := io.ReadAll(response.Body)
			response.Body.Close()
			if response.StatusCode != 200 || string(body) != "packaged-game" {
				t.Fatalf("bad export response: %s", body)
			}
			ready = true
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if !ready {
		t.Fatal("launcher did not serve the packaged game")
	}
	second := exec.Command(bin, "-no-browser", "-port", port)
	if output, err := second.CombinedOutput(); err != nil || !strings.Contains(string(output), "already running") {
		t.Fatalf("second launch: %v %s", err, output)
	}
	// An unrelated process must never be mistaken for SkyJump or replaced.
	occupied, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer occupied.Close()
	other := &http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("other app")) })}
	go other.Serve(occupied)
	defer other.Close()
	_, busyPort, _ := net.SplitHostPort(occupied.Addr().String())
	output, err := exec.Command(bin, "-no-browser", "-port", busyPort).CombinedOutput()
	if err == nil || !strings.Contains(string(output), "in use") {
		t.Fatalf("port collision: %v %s", err, output)
	}
}
