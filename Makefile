MAKEFLAGS += --warn-undefined-variables
SHELL = /bin/bash -o nounset -o errexit -o pipefail
.DEFAULT_GOAL = build
BUILD_DIR  := $(patsubst %/,%,$(abspath $(dir $(lastword $(MAKEFILE_LIST)))))
PARENT_DIR := $(patsubst %/,%,$(dir $(BUILD_DIR)))
UNITY_ASSETS_DIR = ${PARENT_DIR}/arcspace.unity-app/Assets
ARCXR_UNITY_DIR = ${UNITY_ASSETS_DIR}/ArcXR
BUILD_OUTPUT = ${ARCXR_UNITY_DIR}/Plugins
grpc_csharp_exe="${GOPATH}/bin/grpc_csharp_plugin"
LIB_DIR := ${BUILD_DIR}/cmd/archost-lib
GO_BUILD_LIB := cd "${LIB_DIR}" && rm -rf tmp ||: && mkdir tmp && touch main.go && CGO_ENABLED=1 go build -trimpath -buildmode=c-shared 

## display this help message
help:
	@echo -e "\033[32m"
	@echo "go-arcspace"
	@echo "  BUILD_DIR:       ${BUILD_DIR}"
	@echo "  PARENT_DIR:      ${PARENT_DIR}"
	@echo "  BUILD_OUTPUT:    ${BUILD_OUTPUT}"
	@echo
	@awk '/^##.*$$/,/[a-zA-Z_-]+:/' $(MAKEFILE_LIST) | awk '!(NR%2){print $$0p}{p=$$0}' | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m  %-16s\033[0m %s\n", $$1, $$2}' | sort

# ----------------------------------------
# build

GOFILES = $(shell find . -type f -name '*.go')
	
.PHONY: build protos

## build archost and archost-lib
build:  archost archost-lib


#
# https://rogchap.com/2020/09/14/running-go-code-on-ios-and-android/
# TODO: use dynamic linking so that we don't have to restart Unity to load a new binary?
# https://github.com/vladimirvivien/go-cshared-examples  
#


## build archost.dylib for OS X
archost-lib-osx:
# Beware of a Unity bug where *not* selecting "Any CPU" causes the app builder to not add the .dylib to the app bundle!
# Also note that a .dylib is identical to the binary in an OS X .bundle.  Also: https://stackoverflow.com/questions/2339679/what-are-the-differences-between-so-and-dylib-on-macos 
# Info on cross-compiling Go: https://freshman.tech/snippets/go/cross-compile-go-programs/
	GOOS=darwin    GOARCH=amd64  \
	${GO_BUILD_LIB} -o tmp/archost.amd64.dylib . && \
	mv tmp/archost.amd64.dylib "${BUILD_OUTPUT}/macOS/archost.dylib"
#   lipo archost.amd64.dylib archost.arm64.dylib -create -output archost.dylib

## build archost.dylib for iOS
archost-lib-ios:
	GOOS=darwin    GOARCH=arm64  \
	SDK=iphoneos   CC="${LIB_DIR}/clangwrap.sh" \
	${GO_BUILD_LIB} -o tmp/archost.arm64.dylib -tags ios . && \
	mv tmp/archost.arm64.dylib "${BUILD_OUTPUT}/iOS/archost.dylib"

## build archost.dylib for Android
archost-lib-android:

	
## build archost.dylib/DLL for all platforms
archost-lib:  archost-lib-osx archost-lib-ios archost-lib-android


## build archost ("headless" daemon)
archost: $(GOFILES)
	cd cmd/archost && touch main.go && \
	go build -trimpath .

	
## install tools
tools:
	go install github.com/gogo/protobuf/protoc-gen-gogoslick
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc
	go get -d  github.com/gogo/protobuf/proto


## generate .cs and .go from proto files
protos:
#   GrpcTools (2.49.1)
#   Install protoc & grpc_csharp_plugin:
#      - Download latest Grpc.Tools from https://nuget.org/packages/Grpc.Tools
#      - Extract .nupkg as .zip, move protoc and grpc_csharp_plugin to ${GOPATH}/bin 
#   Or, just protoc: https://github.com/protocolbuffers/protobuf/releases
#   Links: https://grpc.io/docs/languages/csharp/quickstart/
	protoc \
	    --gogoslick_out=plugins=grpc:. --gogoslick_opt=paths=source_relative \
	    --csharp_out "${ARCXR_UNITY_DIR}/Arc" \
	    --grpc_out   "${ARCXR_UNITY_DIR}/Arc" \
	    --plugin=protoc-gen-grpc="${grpc_csharp_exe}" \
	    --proto_path=. \
		arc/arc.proto

	protoc \
	    --gogoslick_out=plugins=grpc:. --gogoslick_opt=paths=source_relative \
	    --csharp_out "${ARCXR_UNITY_DIR}/Crates" \
	    --proto_path=. \
		crates/crates.proto

				
	protoc \
	    --gogoslick_out=plugins=grpc:. --gogoslick_opt=paths=source_relative \
	    --proto_path=. \
		ski/api.ski.proto