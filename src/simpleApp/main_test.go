package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthzHandler(t *testing.T) {
	req, err := http.NewRequest("GET", "/healthz", nil)
	if err != nil {
		t.Fatal(err)
	}

	rr := httptest.NewRecorder()
	handler := http.HandlerFunc(healthzHandler)
	handler.ServeHTTP(rr, req)

	if status := rr.Code; status != http.StatusOK {
		t.Errorf("status retornado incorreto: obteve %v esperado %v", status, http.StatusOK)
	}

	if rr.Body.String() != "ok" {
		t.Errorf("corpo retornado incorreto: obteve %v esperado %v", rr.Body.String(), "ok")
	}
}