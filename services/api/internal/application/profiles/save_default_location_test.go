package profiles_test

import (
	"context"
	"testing"

	applicationprofiles "github.com/vendlydigital/help/services/api/internal/application/profiles"
	domainprofiles "github.com/vendlydigital/help/services/api/internal/domain/profiles"
)

type locationWriterSpy struct {
	uid      string
	location domainprofiles.Location
}

func (spy *locationWriterSpy) SaveDefault(
	_ context.Context,
	uid string,
	location domainprofiles.Location,
) error {
	spy.uid = uid
	spy.location = location
	return nil
}

func TestSaveDefaultLocationValidatesBeforeWriting(t *testing.T) {
	t.Parallel()

	writer := &locationWriterSpy{}
	useCase := applicationprofiles.NewSaveDefaultLocation(writer)
	if err := useCase.Execute(
		context.Background(), "firebase-uid", domainprofiles.Location{
			Label: " Casa ", Address: " Rua A, 100 ", City: "Manaus", State: "AM",
			Latitude: -3.1, Longitude: -60.0,
		},
	); err != nil {
		t.Fatalf("Execute() erro inesperado: %v", err)
	}
	if writer.uid != "firebase-uid" || writer.location.Address != "Rua A, 100" {
		t.Fatalf("writer recebeu dados incorretos: %+v", writer)
	}
}
