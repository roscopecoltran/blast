#  Copyright (c) 2017 Minoru Osuka
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# 		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

VERSION = 0.1.1

LDFLAGS = -ldflags "-X \"github.com/roscopecoltran/blast/version.Version=${VERSION}\""

GO := GO15VENDOREXPERIMENT=1 go
PACKAGES = $(shell $(GO) list ./... | grep -v '/vendor/')
PROTOBUFS = $(shell find . -name '*.proto' | sort --unique | grep -v /vendor/)
TARGET_PACKAGES = $(shell find . -name 'main.go' -print0 | xargs -0 -n1 dirname | sort --unique | grep -v /vendor/)
BUILD_TAGS = "-tags=''"
#BUILD_TAGS = "-tags=lang"

PACKAGES = $(shell go list ./... | grep -v /vendor/)

# determine platform
ifeq (Darwin, $(findstring Darwin, $(shell uname -a)))
  PLATFORM 			:= macosx
  GO_BUILD_OS 		:= darwin
else
  PLATFORM 			:= Linux
  GO_BUILD_OS 		:= linux
endif

GREEN 				:= "\\033[1;32m"
NORMAL				:= "\\033[0;39m"
RED					:= "\\033[1;31m"
PINK				:= "\\033[1;35m"
BLUE				:= "\\033[1;34m"
WHITE				:= "\\033[0;02m"
YELLOW				:= "\\033[1;33m"
CYAN				:= "\\033[1;36m"

# git
GIT_BRANCH			:= $(shell git rev-parse --abbrev-ref HEAD)
GIT_VERSION			:= $(shell git describe --always --long --dirty --tags)
GIT_REMOTE_URL		:= $(shell git config --get remote.origin.url)
GIT_TOP_LEVEL		:= $(shell git rev-parse --show-toplevel)

# app
APP_NAME 			:= limo
APP_NAME_UCFIRST 	:= Limo
APP_BRANCH 			:= pkg
APP_DIST_DIR 		:= "$(CURDIR)/dist"

APP_PKG 			:= $(APP_NAME)
APP_PKGS 			:= $(shell go list ./... | grep -v /vendor/)
APP_VER				:= $(APP_VER)
APP_VER_FILE 		:= $(shell git describe --always --long --dirty --tags)

# golang
GO_BUILD_LDFLAGS 	:= -a -ldflags="-X github.com/roscopecoltran/sniperkit-$(APP_NAME)/$(APP_PKG).$(APP_NAME_UCFIRST)Version=${APP_VER}"
GO_BUILD_PREFIX		:= $(APP_DIST_DIR)/all/$(APP_NAME)
GO_BUILD_URI		:= github.com/roscopecoltran/sniperkit-$(APP_NAME)/cmd/$(APP_NAME)
GO_BUILD_VARS 		:= GOARCH=amd64 CGO_ENABLED=0

# https://github.com/derekparker/delve/blob/master/Makefile
GO_VERSION			:= $(shell go version)
GO_BUILD_SHA		:= $(shell git rev-parse HEAD)
LLDB_SERVER			:= $(shell which lldb-server)

# golang - app
GO_BINDATA			:= $(shell which go-bindata)
GO_BINDATA_ASSETFS	:= $(shell which go-bindata-assetfs)
GO_GOX				:= $(shell which gox)
GO_GLIDE			:= $(shell which glide)
GO_VENDORCHECK		:= $(shell which vendorcheck)
GO_LINT				:= $(shell which golint)
GO_DEP				:= $(shell which dep)
GO_ERRCHECK			:= $(shell which errcheck)
GO_UNCONVERT		:= $(shell which unconvert)
GO_INTERFACER		:= $(shell which interfacer)

# general - helper
TR_EXEC				:= $(shell which tr)
AG_EXEC				:= $(shell which ag)

# package managers
BREW_EXEC			:= $(shell which brew)
MACPORTS_EXEC		:= $(shell which ports)
APT_EXEC			:= $(shell which apt-get)
APK_EXEC			:= $(shell which apk)
YUM_EXEC			:= $(shell which yum)
DNF_EXEC			:= $(shell which dnf)

EMERGE_EXEC			:= $(shell which emerge)
PACMAN_EXEC			:= $(shell which pacmane)
SLACKWARE_EXEC		:= $(shell which sbopkg)
ZYPPER_EXEC			:= $(shell which zypper)
PKG_EXEC			:= $(shell which pkg)
PKG_ADD_EXEC		:= $(shell which pkg_add)

gox: $(GO_BUILD_OS)

deps:
	glide install --strip-vendor

dist:
	gox -verbose -os="linux darwin" -arch="amd64" -output="dist/{{.OS}/{{.Dir}}_{{.OS}_{{.Arch}" ./cmd/...

darwin:
	gox -verbose -os="darwin" -arch="amd64" -output="{{.Dir}}" ./cmd/...

linux:
	gox -verbose -os="darwin" -arch="amd64" -output="{{.Dir}}" ./cmd/...

vendoring:
	@echo ">> vendoring dependencies"
	gvt restore

fix-bleve:
	keyword

bleve-fix: install-ag clear-screen ## fix limo, fork, pkg uri for golang package import
	@if [ -d $(CURDIR)/vendor/github.com/Sirupsen ]; then rm -fr vendor/github.com/Sirupsen ; fi
	@echo "fix limo, fork, pkg uri for golang package import"
	@$(AG_EXEC) -l 'github.com/Sirupsen/logrus' --ignore Makefile --ignore *.md vendor | xargs sed -i -e 's/Sirupsen\/logrus/sirupsen\/logrus/g'
	@find . -name "*-e" -exec rm -f {} \; 

protoc:
	@echo ">> generating proto3 code"
	@for proto_file in $(PROTOBUFS); do echo $$proto_file; protoc --go_out=plugins=grpc:. $$proto_file; done

format:
	@echo ">> formatting code"
	@$(GO) fmt $(PACKAGES)

test:
	@echo ">> running all tests"
	@$(GO) test $(PACKAGES)

build:
	@echo ">> building binaries"
	@for target_pkg in $(TARGET_PACKAGES); do echo $$target_pkg; $(GO) build ${BUILD_TAGS} ${LDFLAGS} -o ./bin/`basename $$target_pkg` $$target_pkg; done

install:
	@echo ">> installing binaries"
	@for target_pkg in $(TARGET_PACKAGES); do echo $$target_pkg; $(GO) install ${BUILD_TAGS} ${LDFLAGS} $$target_pkg; done

install-ag: install-ag-$(PLATFORM) ## install the silver searcher (aka. ag)

# if [ "$choice" == 'y' ] && [ "$choice1" == 'y' ]; then
install-ag-macosx: clear-screen ## install the silver searcher on Apple/MacOSX platforms
	@echo "install the silver searcher on Apple/MacOSX platforms"
	@if [ -f $(BREW_EXEC) ] && [ ! -f $(AG_EXEC) ]; 		then $(BREW_EXEC) install the_silver_searcher; fi 
	@if [ -f $(MACPORTS_EXEC) ] && [ ! -f $(AG_EXEC) ]; 	then $(MACPORTS_EXEC) install the_silver_searcher ; fi	

install-ag-linux: clear-screen ## install the silver searcher on Linux platforms
	@echo "install the silver searcher on Linux platforms"
	@if [ -f $(APK_EXEC) ] && [ ! -f $(AG_EXEC) ]; 			then $(APK_EXEC) add --no-cache --update the_silver_searcher ; fi 
	@if [ -f $(APT_EXEC) ] && [ ! -f $(AG_EXEC) ]; 			then $(APT_EXEC) install -f --no-recommend silversearcher-ag ; fi 
	@if [ -f $(YUM_EXEC) ] && [ ! -f $(AG_EXEC) ]; 			then $(YUM_EXEC) install the_silver_searcher ; fi
	@if [ -f $(DNF_EXEC) ] && [ ! -f $(AG_EXEC) ]; 			then $(DNF_EXEC) install the_silver_searcher ; fi
	@if [ -f $(EMERGE_EXEC) ] && [ ! -f $(AG_EXEC) ]; 		then $(EMERGE_EXEC) -a sys-apps/the_silver_searcher ; fi
	@if [ -f $(PACMAN_EXEC) ] && [ ! -f $(AG_EXEC) ]; 		then $(PACMAN_EXEC) -S the_silver_searcher ; fi
	@if [ -f $(SLACKWARE_EXEC) ] && [ ! -f $(AG_EXEC) ]; 	then $(SLACKWARE_EXEC) -i the_silver_searcher ; fi
	@if [ -f $(ZYPPER_EXEC) ] && [ ! -f $(AG_EXEC) ]; 		then $(ZYPPER_EXEC) install the_silver_searcher ; fi
	@if [ -f $(PKG_EXEC) ] && [ ! -f $(AG_EXEC) ]; 			then $(PKG_EXEC) install the_silver_searcher ; fi
	@if [ -f $(PKG_ADD_EXEC) ] && [ ! -f $(AG_EXEC) ]; 		then $(PKG_ADD_EXEC) the_silver_searcher ; fi