package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func healthzHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "ok")
}

func main() {
	http.HandleFunc("/healthz", healthzHandler)

	// Endpoint de métricas para o Prometheus (diferencial para a sua PoC)
	http.Handle("/metrics", promhttp.Handler())

	port := ":8080"
	log.Printf("Servidor rodando na porta %s", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatalf("Erro ao iniciar o servidor: %v", err)
	}
}