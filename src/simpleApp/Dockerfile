FROM golang:1.26-alpine AS builder

WORKDIR /app

COPY main.go .

RUN go mod init minha-app && \
    go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o app .

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=builder /app/app .
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/app"]
