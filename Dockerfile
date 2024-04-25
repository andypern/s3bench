#FROM golang:1.9-alpine as builder
FROM golang:1.13.5-alpine3.10 as builder

RUN apk add --no-cache --purge -uU bash git gcc musl-dev

RUN go get -ldflags "-linkmode external -extldflags -static" github.com/andypern/s3bench

#to build a binary for windows uncomment this line.
#CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go get -ldflags '-extldflags "-static"' github.com/andypern/s3bench

FROM alpine:3.12

COPY --from=builder /go/bin/s3bench /usr/local/bin 

ENTRYPOINT ["/usr/local/bin/s3bench"]
