package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

var routePattern = regexp.MustCompile(`"(GET|POST|PUT|PATCH|DELETE) (/[^"\s]+)"`)

type collection struct {
	Info     map[string]string `json:"info"`
	Auth     map[string]any    `json:"auth"`
	Variable []map[string]any  `json:"variable"`
	Item     []folder          `json:"item"`
}

type folder struct {
	Name string `json:"name"`
	Item []item `json:"item"`
}
type item struct {
	Name    string  `json:"name"`
	Request request `json:"request"`
}
type request struct {
	Method string              `json:"method"`
	Header []map[string]string `json:"header,omitempty"`
	Body   *body               `json:"body,omitempty"`
	URL    string              `json:"url"`
	Auth   map[string]any      `json:"auth,omitempty"`
}
type body struct {
	Mode    string         `json:"mode"`
	Raw     string         `json:"raw"`
	Options map[string]any `json:"options"`
}

func main() {
	routerPath := filepath.Join("internal", "adapters", "httpapi", "router.go")
	source, err := os.ReadFile(routerPath)
	if err != nil {
		panic(err)
	}
	folders := map[string][]item{}
	seen := map[string]bool{}
	for _, match := range routePattern.FindAllStringSubmatch(string(source), -1) {
		method, path := match[1], match[2]
		key := method + " " + path
		if seen[key] {
			continue
		}
		seen[key] = true
		folderName := routeFolder(path)
		folders[folderName] = append(folders[folderName], newItem(method, path))
	}
	names := make([]string, 0, len(folders))
	for name := range folders {
		names = append(names, name)
	}
	sort.Strings(names)
	groups := make([]folder, 0, len(names))
	for _, name := range names {
		sort.Slice(folders[name], func(i, j int) bool { return folders[name][i].Name < folders[name][j].Name })
		groups = append(groups, folder{Name: name, Item: folders[name]})
	}
	result := collection{
		Info: map[string]string{
			"_postman_id": "b91126a4-a204-4b67-bbb4-46a7fc251d7f",
			"name":        "Help API", "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
		},
		Auth: bearerAuth(),
		Variable: []map[string]any{
			{"key": "base_url", "value": "https://lucas.tailc561e1.ts.net", "type": "string"},
			{"key": "id_token", "value": "", "type": "string"},
			{"key": "id", "value": "", "type": "string"},
			{"key": "uid", "value": "", "type": "string"},
		},
		Item: groups,
	}
	encoded, err := json.MarshalIndent(result, "", "  ")
	if err != nil {
		panic(err)
	}
	output := filepath.Join("..", "..", "postman", "Help API.postman_collection.json")
	if err = os.MkdirAll(filepath.Dir(output), 0o755); err != nil {
		panic(err)
	}
	if err = os.WriteFile(output, append(encoded, '\n'), 0o644); err != nil {
		panic(err)
	}
	fmt.Printf("generated %d routes at %s\n", len(seen), output)
}

func newItem(method, path string) item {
	postmanPath := regexp.MustCompile(`\{([^}]+)\}`).ReplaceAllString(path, `:$1`)
	requestValue := request{Method: method, URL: "{{base_url}}" + postmanPath}
	if method != "GET" && method != "DELETE" && !strings.Contains(path, "/avatar") && !strings.Contains(path, "/portfolio") {
		requestValue.Header = []map[string]string{{"key": "Content-Type", "value": "application/json"}}
		requestValue.Body = &body{Mode: "raw", Raw: exampleBody(method, path), Options: map[string]any{"raw": map[string]string{"language": "json"}}}
	}
	if path == "/health" || path == "/ready" || strings.HasPrefix(path, "/v1/auth/") || (method == "GET" && strings.Contains(path, "/profile/portfolio/")) {
		requestValue.Auth = map[string]any{"type": "noauth"}
	}
	return item{Name: method + " " + path, Request: requestValue}
}

func exampleBody(method, path string) string {
	switch {
	case path == "/v1/profile" && method == "POST":
		return `{"display_name":"Maria Silva","role":"customer"}`
	case path == "/v1/profile" && method == "PUT":
		return `{"display_name":"Maria Silva","phone":"92999999999","contact_preference":"chat","photo_visibility":"everyone","last_seen_visibility":"conversations","show_online":true,"allow_conversation_requests":true,"professional":null}`
	case strings.HasSuffix(path, "/reviews/mine"):
		return `{"rating":5,"comment":"Ótima experiência"}`
	case strings.HasSuffix(path, "/transitions"):
		return `{"client_command_id":"{{$guid}}","target_status":"accepted","expected_version":0,"reason":""}`
	case strings.HasSuffix(path, "/reschedule"):
		return `{"client_command_id":"{{$guid}}","scheduled_for":"2026-08-20T14:00:00Z","expected_version":0}`
	case strings.Contains(path, "/help-now/requests") && method == "POST":
		return `{"client_request_id":"{{$guid}}","category_id":"","note":"Preciso de ajuda","latitude":-3.1,"longitude":-60.0,"address_label":"Local atual","formatted_address":"Manaus - AM"}`
	case strings.Contains(path, "/responses"):
		return `{"client_command_id":"{{$guid}}","action":"accept"}`
	case strings.HasSuffix(path, "/decision"):
		return `{"accept":true}`
	case path == "/v1/chat/conversations/direct":
		return `{"user_id":"{{uid}}"}`
	case path == "/v1/auth/password-reset":
		return `{"email":"usuario@exemplo.com"}`
	default:
		return `{}`
	}
}

func bearerAuth() map[string]any {
	return map[string]any{
		"type": "bearer", "bearer": []map[string]string{{"key": "token", "value": "{{id_token}}", "type": "string"}},
	}
}

func routeFolder(path string) string {
	parts := strings.Split(strings.Trim(path, "/"), "/")
	if len(parts) == 0 {
		return "System"
	}
	if parts[0] == "v1" && len(parts) > 1 {
		return strings.Title(strings.ReplaceAll(parts[1], "-", " "))
	}
	return "System"
}
