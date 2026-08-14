package mailersend

import (
	"bytes"
	"html/template"
)

const emailVerificationTemplateSource = `<!doctype html>
<html lang="pt-BR"><body style="margin:0;background:#f8faf8;font-family:Arial,sans-serif;color:#17211b">
<table width="100%" cellpadding="0" cellspacing="0" role="presentation"><tr><td align="center" style="padding:32px 16px">
<table width="100%" style="max-width:560px;background:#fff;border:1px solid #e9ede9;border-radius:16px" cellpadding="0" cellspacing="0" role="presentation">
<tr><td style="padding:32px"><div style="font-size:24px;font-weight:800;color:#174d38">Help</div>
<h1 style="font-size:24px;margin:28px 0 12px">Confirme seu e-mail</h1>
<p style="font-size:15px;line-height:1.6;color:#69736d">Falta só confirmar seu endereço para ativar sua conta.</p>
<p style="margin:28px 0"><a href="{{.}}" style="display:inline-block;background:#4f9e6c;color:#fff;text-decoration:none;font-weight:700;padding:14px 22px;border-radius:12px">Confirmar meu e-mail</a></p>
<p style="font-size:12px;line-height:1.5;color:#69736d">Se você não criou esta conta, ignore este e-mail.</p>
</td></tr></table></td></tr></table></body></html>`

var emailVerificationTemplate = template.Must(
	template.New("email-verification").Parse(emailVerificationTemplateSource),
)

func renderEmailVerificationHTML(link string) (string, error) {
	var output bytes.Buffer
	if err := emailVerificationTemplate.Execute(&output, link); err != nil {
		return "", err
	}
	return output.String(), nil
}
