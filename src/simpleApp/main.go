package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var httpRequestsTotal = prometheus.NewCounterVec(
	prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total de requisições HTTP recebidas",
	},
	[]string{"path"},
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
}

func rootHandler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		httpRequestsTotal.WithLabelValues("404").Inc()
		log.Printf("[HTTP] %s %s - 404 Not Found from %s", r.Method, r.URL.Path, r.RemoteAddr)
		http.NotFound(w, r)
		return
	}

	httpRequestsTotal.WithLabelValues("/").Inc()

	version := os.Getenv("APP_VERSION")
	if version == "" {
		version = "v1"
	}

	log.Printf("[HTTP] %s %s - 200 OK (Version: %s, Remote: %s)", r.Method, r.URL.Path, version, r.RemoteAddr)

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, "<h1>Minha App (%s)</h1><p>Aplicação rodando no cluster Kubernetes via Argo CD / Rollouts!</p>", version)
}

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	httpRequestsTotal.WithLabelValues("/healthz").Inc()
	log.Printf("[HEALTHZ] %s %s - 200 OK from %s", r.Method, r.URL.Path, r.RemoteAddr)
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func main() {
	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/healthz", healthzHandler)

	// Endpoint de métricas para o Prometheus (diferencial para a sua PoC)
	http.Handle("/metrics", promhttp.Handler())

	port := ":8080"
	log.Printf("Servidor rodando na porta %s", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Erro ao iniciar o servidor: %v", err)
	}
}
