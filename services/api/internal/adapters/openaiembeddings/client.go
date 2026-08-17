package openaiembeddings

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/vendlydigital/help/services/api/internal/domain/matchmaking"
)

const maxCandidates = 40

type Config struct {
	APIKey, BaseURL, Model string
	Timeout                time.Duration
}

type Client struct {
	config Config
	http   *http.Client
	cache  *vectorCache
}

type Usage struct{ PromptTokens, TotalTokens int }

func NewClient(config Config) *Client {
	return &Client{config: config, http: &http.Client{Timeout: config.Timeout}, cache: newVectorCache(512, 24*time.Hour)}
}

func (client *Client) Score(ctx context.Context, intent string, candidates []matchmaking.Candidate) (map[string]float64, error) {
	if len(candidates) > maxCandidates {
		candidates = candidates[:maxCandidates]
	}
	texts := make([]string, 1, len(candidates)+1)
	texts[0] = strings.TrimSpace(intent)
	ids := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		service := candidate.Listing.Service
		texts = append(texts, strings.TrimSpace(service.Title+". "+service.Description+". "+candidate.Listing.ProviderName))
		ids = append(ids, service.ID)
	}
	vectors, _, err := client.Embed(ctx, texts)
	if err != nil {
		return nil, err
	}
	if len(vectors) != len(texts) {
		return nil, errors.New("OpenAI returned an incomplete embedding batch")
	}
	result := make(map[string]float64, len(ids))
	for index, id := range ids {
		result[id] = cosine(vectors[0], vectors[index+1])
	}
	return result, nil
}

func (client *Client) Embed(ctx context.Context, texts []string) ([][]float32, Usage, error) {
	if len(texts) == 0 {
		return nil, Usage{}, nil
	}
	vectors := make([][]float32, len(texts))
	missingTexts, missingIndexes := make([]string, 0, len(texts)), make([]int, 0, len(texts))
	for index, value := range texts {
		if vector, ok := client.cache.get(value); ok {
			vectors[index] = vector
		} else {
			missingTexts, missingIndexes = append(missingTexts, value), append(missingIndexes, index)
		}
	}
	if len(missingTexts) == 0 {
		return vectors, Usage{}, nil
	}
	batch, usage, err := client.request(ctx, missingTexts)
	if err != nil {
		return nil, Usage{}, err
	}
	if len(batch) != len(missingTexts) {
		return nil, Usage{}, errors.New("OpenAI returned an incomplete embedding batch")
	}
	for index, vector := range batch {
		originalIndex := missingIndexes[index]
		vectors[originalIndex] = vector
		client.cache.put(missingTexts[index], vector)
	}
	return vectors, usage, nil
}

func (client *Client) request(ctx context.Context, texts []string) ([][]float32, Usage, error) {
	payload, err := json.Marshal(map[string]any{"model": client.config.Model, "input": texts, "encoding_format": "float"})
	if err != nil {
		return nil, Usage{}, fmt.Errorf("encode embeddings request: %w", err)
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(client.config.BaseURL, "/")+"/embeddings", bytes.NewReader(payload))
	if err != nil {
		return nil, Usage{}, fmt.Errorf("create embeddings request: %w", err)
	}
	request.Header.Set("Authorization", "Bearer "+client.config.APIKey)
	request.Header.Set("Content-Type", "application/json")
	response, err := client.http.Do(request)
	if err != nil {
		return nil, Usage{}, fmt.Errorf("request embeddings: %w", err)
	}
	defer response.Body.Close()
	body, err := io.ReadAll(io.LimitReader(response.Body, 8<<20))
	if err != nil {
		return nil, Usage{}, fmt.Errorf("read embeddings response: %w", err)
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, Usage{}, fmt.Errorf("OpenAI embeddings returned status %d", response.StatusCode)
	}
	var result struct {
		Data []struct {
			Index     int       `json:"index"`
			Embedding []float32 `json:"embedding"`
		} `json:"data"`
		Usage struct {
			PromptTokens int `json:"prompt_tokens"`
			TotalTokens  int `json:"total_tokens"`
		} `json:"usage"`
	}
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, Usage{}, fmt.Errorf("decode embeddings response: %w", err)
	}
	vectors := make([][]float32, len(texts))
	for _, item := range result.Data {
		if item.Index < 0 || item.Index >= len(vectors) || len(item.Embedding) == 0 {
			return nil, Usage{}, errors.New("OpenAI returned an invalid embedding item")
		}
		vectors[item.Index] = item.Embedding
	}
	for _, vector := range vectors {
		if len(vector) == 0 {
			return nil, Usage{}, errors.New("OpenAI returned an incomplete embedding batch")
		}
	}
	return vectors, Usage{PromptTokens: result.Usage.PromptTokens, TotalTokens: result.Usage.TotalTokens}, nil
}

func cosine(left, right []float32) float64 {
	if len(left) == 0 || len(left) != len(right) {
		return 0
	}
	var dot, leftNorm, rightNorm float64
	for index := range left {
		l, r := float64(left[index]), float64(right[index])
		dot, leftNorm, rightNorm = dot+l*r, leftNorm+l*l, rightNorm+r*r
	}
	if leftNorm == 0 || rightNorm == 0 {
		return 0
	}
	return math.Max(0, math.Min(1, dot/(math.Sqrt(leftNorm)*math.Sqrt(rightNorm))))
}

type cachedVector struct {
	value    []float32
	storedAt time.Time
}

type vectorCache struct {
	mutex   sync.Mutex
	items   map[[32]byte]cachedVector
	maximum int
	ttl     time.Duration
}

func newVectorCache(maximum int, ttl time.Duration) *vectorCache {
	return &vectorCache{items: make(map[[32]byte]cachedVector), maximum: maximum, ttl: ttl}
}

func (cache *vectorCache) get(text string) ([]float32, bool) {
	cache.mutex.Lock()
	defer cache.mutex.Unlock()
	item, ok := cache.items[sha256.Sum256([]byte(text))]
	if !ok || time.Since(item.storedAt) > cache.ttl {
		return nil, false
	}
	return item.value, true
}

func (cache *vectorCache) put(text string, vector []float32) {
	cache.mutex.Lock()
	defer cache.mutex.Unlock()
	if len(cache.items) >= cache.maximum {
		var oldestKey [32]byte
		oldest := time.Now()
		for key, item := range cache.items {
			if item.storedAt.Before(oldest) {
				oldestKey, oldest = key, item.storedAt
			}
		}
		delete(cache.items, oldestKey)
	}
	cache.items[sha256.Sum256([]byte(text))] = cachedVector{value: vector, storedAt: time.Now()}
}
