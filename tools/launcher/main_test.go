package main

import (
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestServeExport(t *testing.T) {
	root := filepath.Join(t.TempDir(), "Игра с пробелами")
	if err := os.MkdirAll(root, 0755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"index.html", "index.js", "index.wasm", "index.pck"} {
		if err := os.WriteFile(filepath.Join(root, name), []byte("game bytes"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if err := validateBuild(root); err != nil {
		t.Fatal(err)
	}
	handler := gameHandler(root)
	for _, test := range []struct {
		path, method, host, mime string
		status                   int
	}{
		{"/", "GET", "127.0.0.1:4174", "text/html; charset=utf-8", 200},
		{"/index.wasm", "GET", "127.0.0.1:4174", "application/wasm", 200},
		{"/index.pck", "HEAD", "127.0.0.1:4174", "application/octet-stream", 200},
		{"/__skyjump/health", "GET", "127.0.0.1:4174", "text/plain", 200},
		{"/", "POST", "127.0.0.1:4174", "", 405},
		{"/", "GET", "attacker.test:4174", "", 403},
		{"/../secret", "GET", "127.0.0.1:4174", "", 404},
		{"/index.%2e%2e%2fsecret", "GET", "127.0.0.1:4174", "", 404},
		{"/index.%5csecret", "GET", "127.0.0.1:4174", "", 404},
		{"/index.missing", "GET", "127.0.0.1:4174", "", 404},
	} {
		t.Run(test.method+test.path+test.host, func(t *testing.T) {
			req := httptest.NewRequest(test.method, "http://127.0.0.1:4174"+test.path, nil)
			req.Host = test.host
			res := httptest.NewRecorder()
			handler.ServeHTTP(res, req)
			if res.Code != test.status {
				t.Fatalf("status %d, want %d", res.Code, test.status)
			}
			if test.mime != "" && res.Header().Get("Content-Type") != test.mime {
				t.Fatalf("MIME: %s", res.Header().Get("Content-Type"))
			}
			if test.method == "HEAD" && res.Body.Len() != 0 {
				t.Fatal("HEAD has body")
			}
		})
	}
	if err := os.WriteFile(filepath.Join(root, "index.pck"), []byte("version https://git-lfs.github.com/spec/v1\noid sha256:abc"), 0644); err != nil {
		t.Fatal(err)
	}
	if validateBuild(root) == nil {
		t.Fatal("LFS pointer accepted as game")
	}
	os.Remove(filepath.Join(root, "index.pck"))
	if validateBuild(root) == nil {
		t.Fatal("missing export accepted")
	}
}
