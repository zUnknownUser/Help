package openaiembeddings

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"
)

func TestEmbedBatchesAndCachesVectors(t *testing.T) {
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Header.Get("Authorization") != "Bearer secret" {
			t.Fatal("authorization header missing")
		}
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"data":[{"index":0,"embedding":[1,0]},{"index":1,"embedding":[0,1]}],"usage":{"prompt_tokens":2,"total_tokens":2}}`)
	}))
	defer server.Close()
	client := NewClient(Config{APIKey: "secret", BaseURL: server.URL, Model: "test", Timeout: time.Second})

	first, usage, err := client.Embed(context.Background(), []string{"a", "b"})
	second, cachedUsage, cachedErr := client.Embed(context.Background(), []string{"a", "b"})

	if err != nil || cachedErr != nil || len(first) != 2 || len(second) != 2 {
		t.Fatalf("embed errors = %v/%v", err, cachedErr)
	}
	if calls.Load() != 1 || usage.TotalTokens != 2 || cachedUsage.TotalTokens != 0 {
		t.Fatalf("calls=%d usage=%+v cached=%+v", calls.Load(), usage, cachedUsage)
	}
}

func TestCosineRejectsInvalidVectors(t *testing.T) {
	if cosine([]float32{1}, []float32{1, 2}) != 0 {
		t.Fatal("invalid vector dimensions must have zero similarity")
	}
}
