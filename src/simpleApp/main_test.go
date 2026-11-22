package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func TestHealthzHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	healthzHandler(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("esperava status %d, obteve %d", http.StatusOK, rec.Code)
	}

	if body := rec.Body.String(); body != "ok" {
		t.Errorf("esperava body 'ok', obteve '%s'", body)
	}
}

func TestRootHandler(t *testing.T) {
	t.Setenv("APP_VERSION", "v1-teste")

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()

	rootHandler(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("esperava status %d, obteve %d", http.StatusOK, rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, "Minha App (v1-teste)") {
		t.Errorf("esperava encontrar 'Minha App (v1-teste)' no body, obteve '%s'", body)
	}
}

func TestRootHandlerNotFound(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/rota-inexistente", nil)
	rec := httptest.NewRecorder()

	rootHandler(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("esperava status %d para rota inexistente, obteve %d", http.StatusNotFound, rec.Code)
	}
}

func TestMetricsHandler(t *testing.T) {
	// Faz uma requisição na raiz para garantir que o contador seja incrementado
	rootReq := httptest.NewRequest(http.MethodGet, "/", nil)
	rootHandler(httptest.NewRecorder(), rootReq)

	// Consulta o endpoint /metrics
	req := httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec := httptest.NewRecorder()

	promhttp.Handler().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("esperava status %d, obteve %d", http.StatusOK, rec.Code)
	}

	body := rec.Body.String()
	if !strings.Contains(body, `http_requests_total{path="/"}`) {
		t.Errorf("métrica 'http_requests_total' não encontrada na saída de /metrics")
	}
}
