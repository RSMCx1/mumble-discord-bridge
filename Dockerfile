# Build stage - Alpine for musl consistency
FROM golang:1.26-alpine AS builder

WORKDIR /go/src/app
COPY . .

# Install build dependencies
RUN apk add --no-cache git make opus-dev gcc musl-dev g++ cmake ninja zip unzip curl pkgconfig perl bash

# Install libdave (Discord DAVE E2EE protocol)
RUN export VCPKG_FORCE_SYSTEM_BINARIES=1 && \
    export CXXFLAGS="-Wno-error=maybe-uninitialized" && \
    NON_INTERACTIVE=1 FORCE_BUILD=1 bash scripts/libdave_install.sh v1.1.0 && \
    export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH"

# Build with version info
ARG VERSION=dev
ARG COMMIT=unknown
ARG DATE=unknown
RUN export PKG_CONFIG_PATH="$HOME/.local/lib/pkgconfig:$PKG_CONFIG_PATH" && \
    CGO_ENABLED=1 go build -tags=netgo \
    -ldflags="-s -w -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.date=${DATE}" \
    -o /mumble-discord-bridge \
    ./cmd/mumble-discord-bridge

# Generate licenses
RUN go install github.com/google/go-licenses@latest && \
    go-licenses save ./cmd/mumble-discord-bridge --force --save_path="/LICENSES"

# Runtime stage - Alpine
FROM alpine:latest

WORKDIR /opt/
RUN apk add --no-cache opus libstdc++

COPY --from=builder /root/.local/lib/libdave.so /usr/lib/
COPY --from=builder /LICENSES ./LICENSES
COPY --from=builder /mumble-discord-bridge .

CMD ["/opt/mumble-discord-bridge"]
