// SkyJump's offline Web player. The game itself remains a Godot Web export.
package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"
)

var buildID = "development"

func gameHandler(root string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host, _, err := net.SplitHostPort(r.Host)
		if err != nil || host != "127.0.0.1" {
			http.Error(w, "Use the 127.0.0.1 address shown by SkyJump.", http.StatusForbidden)
			return
		}
		w.Header().Set("X-SkyJump", buildID)
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Cache-Control", "no-cache")
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			w.Header().Set("Allow", "GET, HEAD")
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if r.URL.Path == "/__skyjump/health" {
			w.Header().Set("Content-Type", "text/plain")
			fmt.Fprint(w, buildID)
			return
		}
		name := strings.TrimPrefix(r.URL.Path, "/")
		if name == "" {
			name = "index.html"
		}
		// Only the root export files are public. No directory browsing, links or source files.
		if !strings.HasPrefix(name, "index.") || strings.ContainsAny(name, "/\\:") {
			http.NotFound(w, r)
			return
		}
		file := filepath.Join(root, name)
		info, err := os.Lstat(file)
		if err != nil || !info.Mode().IsRegular() {
			http.NotFound(w, r)
			return
		}
		types := map[string]string{".html": "text/html; charset=utf-8", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png", ".svg": "image/svg+xml"}
		if kind := types[filepath.Ext(name)]; kind != "" {
			w.Header().Set("Content-Type", kind)
		}
		http.ServeFile(w, r, file)
	})
}

func validateBuild(root string) error {
	for _, name := range []string{"index.html", "index.js", "index.wasm", "index.pck"} {
		file, err := os.Open(filepath.Join(root, name))
		if err != nil {
			return fmt.Errorf("missing web/%s: extract the WHOLE game archive first", name)
		}
		prefix := make([]byte, 128)
		n, _ := file.Read(prefix)
		file.Close()
		if n == 0 || strings.HasPrefix(string(prefix[:n]), "version https://git-lfs.github.com/spec/") {
			return fmt.Errorf("web/%s is not a game file; download the playable release, not Source code", name)
		}
	}
	return nil
}

func openBrowser(url string) {
	var command *exec.Cmd
	if runtime.GOOS == "windows" {
		command = exec.Command("rundll32.exe", "url.dll,FileProtocolHandler", url)
	} else {
		command = exec.Command("xdg-open", url)
	}
	if err := command.Start(); err != nil {
		fmt.Println("Open this address in your browser:", url)
	} else {
		go command.Wait()
	}
}

func run() error {
	noBrowser := flag.Bool("no-browser", false, "Do not open a browser automatically")
	port := flag.Int("port", 4174, "Local port (changing it creates separate browser saves)")
	flag.Parse()
	if *port < 1 || *port > 65535 {
		return errors.New("invalid port")
	}
	bin, err := os.Executable()
	if err != nil {
		return err
	}
	root := filepath.Join(filepath.Dir(bin), "web")
	if err := validateBuild(root); err != nil {
		return err
	}
	address := "127.0.0.1:" + strconv.Itoa(*port)
	url := "http://" + address + "/"
	listener, err := net.Listen("tcp4", address)
	if err != nil {
		client := &http.Client{Timeout: time.Second, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}
		response, probeErr := client.Get(url + "__skyjump/health")
		if probeErr == nil {
			body, _ := io.ReadAll(io.LimitReader(response.Body, 256))
			response.Body.Close()
			if response.StatusCode == 200 && string(body) == buildID && response.Header.Get("X-SkyJump") == buildID {
				fmt.Println("SkyJump is already running:", url)
				if !*noBrowser {
					openBrowser(url)
				}
				return nil
			}
		}
		return fmt.Errorf("port %d is in use. Close the previous local game/server, then try again", *port)
	}
	server := &http.Server{Handler: gameHandler(root), ReadHeaderTimeout: 5 * time.Second, IdleTimeout: 60 * time.Second}
	stop, cancel := signal.NotifyContext(context.Background(), os.Interrupt)
	defer cancel()
	go func() { <-stop.Done(); server.Close() }()
	fmt.Println("SkyJump — offline Web player")
	fmt.Println(url)
	fmt.Println("Keep this window open while playing. Close it or press Ctrl+C to stop.")
	fmt.Println("The game is available only on this computer. Godot and internet are not required.")
	if !*noBrowser {
		openBrowser(url)
	}
	err = server.Serve(listener)
	if errors.Is(err, http.ErrServerClosed) {
		return nil
	}
	return err
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "SkyJump:", err)
		// A double-clicked Windows console must keep errors visible.
		if runtime.GOOS == "windows" && len(os.Args) == 1 {
			fmt.Println("Press Enter to close.")
			bufio.NewReader(os.Stdin).ReadString('\n')
		}
		os.Exit(1)
	}
}
