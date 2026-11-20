FROM golang:1.26-alpine AS builder

WORKDIR /app

# Baixa as dependências antes de copiar o main.go
RUN go mod init minha-app && \
    go get github.com/prometheus/client_golang/prometheus/promhttp

COPY main.go .

RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o app .

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=builder /app/app .
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/app"]