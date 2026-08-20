package httpapi_test

import (
	"bytes"
	"context"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"net/textproto"
	"testing"

	"github.com/vendlydigital/help/services/api/internal/adapters/httpapi"
	"github.com/vendlydigital/help/services/api/internal/application/ports"
	domainrequests "github.com/vendlydigital/help/services/api/internal/domain/servicerequests"
)

type negotiationServiceStub struct {
	contentType string
}

func (stub *negotiationServiceStub) Get(context.Context, string, string) (ports.ServiceRequestNegotiationResult, error) {
	return ports.ServiceRequestNegotiationResult{}, nil
}

func (stub *negotiationServiceStub) Propose(context.Context, string, string, ports.ServiceRequestQuoteInput) (ports.ServiceRequestNegotiationResult, error) {
	return ports.ServiceRequestNegotiationResult{}, nil
}

func (stub *negotiationServiceStub) Accept(context.Context, string, string, string, ports.ServiceRequestQuoteAcceptInput) (ports.ServiceRequestNegotiationResult, error) {
	return ports.ServiceRequestNegotiationResult{}, nil
}

func (stub *negotiationServiceStub) UploadAttachment(_ context.Context, _, _, contentType, _ string, _ io.Reader) (domainrequests.Attachment, error) {
	stub.contentType = contentType
	if contentType != "image/jpeg" {
		return domainrequests.Attachment{}, domainrequests.ErrInvalidAttachment
	}
	return domainrequests.Attachment{
		ID: "8280806e-c144-461a-8f06-f797d9be434b", ContentType: contentType, ByteSize: 11,
	}, nil
}

func (stub *negotiationServiceStub) OpenAttachment(context.Context, string, string) (domainrequests.Attachment, ports.MediaObject, error) {
	return domainrequests.Attachment{}, ports.MediaObject{}, nil
}

func (stub *negotiationServiceStub) DeleteAttachment(context.Context, string, string, string) error {
	return nil
}

func TestRequestAttachmentUploadUsesDetectedContentInsteadOfAdvertisedMIME(t *testing.T) {
	t.Parallel()
	stub := &negotiationServiceStub{}
	handler := httpapi.NewServiceRequestNegotiationHandler(stub)
	request := multipartAttachmentRequest(t, []byte("<script>bad</script>"), "image/jpeg")
	response := httptest.NewRecorder()

	handler.UploadAttachment(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, body = %s", response.Code, response.Body.String())
	}
	if stub.contentType == "image/jpeg" {
		t.Fatalf("trusted advertised content type %q", stub.contentType)
	}
}

func TestRequestAttachmentUploadAcceptsDetectedJPEG(t *testing.T) {
	t.Parallel()
	stub := &negotiationServiceStub{}
	handler := httpapi.NewServiceRequestNegotiationHandler(stub)
	jpeg := []byte{0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 'J', 'F', 'I', 'F', 0x00}
	request := multipartAttachmentRequest(t, jpeg, "application/octet-stream")
	response := httptest.NewRecorder()

	handler.UploadAttachment(response, request)

	if response.Code != http.StatusCreated || stub.contentType != "image/jpeg" {
		t.Fatalf("status = %d, type = %q, body = %s", response.Code, stub.contentType, response.Body.String())
	}
}

func multipartAttachmentRequest(t *testing.T, content []byte, advertisedType string) *http.Request {
	t.Helper()
	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	header := textproto.MIMEHeader{}
	header.Set("Content-Disposition", `form-data; name="file"; filename="request.jpg"`)
	header.Set("Content-Type", advertisedType)
	part, err := writer.CreatePart(header)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = part.Write(content); err != nil {
		t.Fatal(err)
	}
	if err = writer.Close(); err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, "/v1/service-requests/request/attachments", body)
	request.Header.Set("Content-Type", writer.FormDataContentType())
	request.SetPathValue("id", "c349a83e-fbd9-4d59-984d-0516b7f981b2")
	return request
}
