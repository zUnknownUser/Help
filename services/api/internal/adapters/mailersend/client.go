package mailersend

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"net/http"
	"strings"
	"time"

	"github.com/vendlydigital/help/services/api/internal/application/ports"
)

const defaultBaseURL = "https://api.mailersend.com"

type Config struct {
	BaseURL    string
	APIToken   string
	FromEmail  string
	FromName   string
	HTTPClient *http.Client
}

type Client struct {
	baseURL    string
	apiToken   string
	fromEmail  string
	fromName   string
	httpClient *http.Client
}

func NewClient(config Config) *Client {
	baseURL := strings.TrimRight(config.BaseURL, "/")
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	httpClient := config.HTTPClient
	if httpClient == nil {
		httpClient = &http.Client{Timeout: 10 * time.Second}
	}
	return &Client{
		baseURL:    baseURL,
		apiToken:   config.APIToken,
		fromEmail:  config.FromEmail,
		fromName:   config.FromName,
		httpClient: httpClient,
	}
}

func (c *Client) SendPasswordReset(ctx context.Context, message ports.PasswordResetEmail) error {
	htmlBody, err := renderPasswordResetHTML(message.ResetLink)
	if err != nil {
		return fmt.Errorf("render template: %w", err)
	}
	return c.send(
		ctx,
		message.To.String(),
		"Redefina sua senha do Help",
		htmlBody,
		"Recebemos uma solicitação para redefinir sua senha do Help. Acesse: "+message.ResetLink,
	)
}

func (c *Client) SendEmailVerification(
	ctx context.Context,
	message ports.EmailVerificationEmail,
) error {
	htmlBody, err := renderEmailVerificationHTML(message.VerificationLink)
	if err != nil {
		return fmt.Errorf("render template: %w", err)
	}
	return c.send(
		ctx,
		message.To.String(),
		"Confirme seu e-mail do Help",
		htmlBody,
		"Confirme seu e-mail para ativar sua conta do Help. Acesse: "+message.VerificationLink,
	)
}

func (c *Client) send(ctx context.Context, to, subject, htmlBody, textBody string) error {
	payload := map[string]any{
		"from":    map[string]string{"email": c.fromEmail, "name": c.fromName},
		"to":      []map[string]string{{"email": to}},
		"subject": subject,
		"html":    htmlBody,
		"text":    textBody,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("encode payload: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/v1/email", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.apiToken)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")

	res, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("send request: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusAccepted {
		return fmt.Errorf("mailersend returned HTTP %d", res.StatusCode)
	}
	return nil
}

const passwordResetTemplateSource = `<!doctype html>
<html lang="pt-BR"><body style="margin:0;background:#f8faf8;font-family:Arial,sans-serif;color:#17211b">
<table width="100%" cellpadding="0" cellspacing="0" role="presentation"><tr><td align="center" style="padding:32px 16px">
<table width="100%" style="max-width:560px;background:#fff;border:1px solid #e9ede9;border-radius:16px" cellpadding="0" cellspacing="0" role="presentation">
<tr><td style="padding:32px"><div style="font-size:24px;font-weight:800;color:#174d38">Help</div>
<h1 style="font-size:24px;margin:28px 0 12px">Redefina sua senha</h1>
<p style="font-size:15px;line-height:1.6;color:#69736d">Recebemos uma solicitação para criar uma nova senha para sua conta.</p>
<p style="margin:28px 0"><a href="{{.}}" style="display:inline-block;background:#4f9e6c;color:#fff;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:12px">Criar nova senha</a></p>
<p style="font-size:12px;line-height:1.5;color:#69736d">Se você não solicitou esta alteração, ignore este e-mail. Sua senha continuará a mesma.</p>
</td></tr></table></td></tr></table></body></html>`

var passwordResetTemplate = template.Must(
	template.New("password-reset").Parse(passwordResetTemplateSource),
)

func renderPasswordResetHTML(resetLink string) (string, error) {
	var output bytes.Buffer
	if err := passwordResetTemplate.Execute(&output, resetLink); err != nil {
		return "", err
	}
	return output.String(), nil
}
