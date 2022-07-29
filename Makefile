################################################################################
#
#  Copyright (C) 2022 Garrett Brown
#  This file is part of oasis-manifest - https://github.com/eigendude/oasis-manifest
#
#  SPDX-License-Identifier: Apache-2.0
#  See LICENSES/README.md for more information.
#
################################################################################

.PHONY: all
all: image

# Set shell to bash to source environment variables
SHELL := /bin/bash

# Get distro name from local.conf file
DISTRO := $(shell grep -w -m 1 DISTRO conf/local.conf | grep -v '^\#' | awk -F\" '{print $$2}')

#
# Distro flavor
#
# The distro comes in several flavors:
#
#   - (empty) - The standard distribution
#   - sdk - An image suited for development
#   - debug - Includes debug symbols and development tools
#   - zeus - The image is based on Yocto 3.0 Zeus
#   - dashing - Replaces ROS 1 with ROS 2 Dashing
#   - eloquent - Replaces ROS 1 with ROS 2 Eloquent
DISTRO_FLAVOR :=

# Get distro version from local.conf file
VERSION_MAJOR := $(shell grep -w -m 1 VERSION_MAJOR conf/local.conf | grep -v '^\#' | awk -F\" '{print $$2}')
VERSION_MINOR := $(shell grep -w -m 1 VERSION_MINOR conf/local.conf | grep -v '^\#' | awk -F\" '{print $$2}')
VERSION_PATCH := $(shell grep -w -m 1 VERSION_PATCH conf/local.conf | grep -v '^\#' | awk -F\" '{print $$2}')
VERSION_TAG := $(shell grep -w -m 1 VERSION_TAG conf/local.conf | grep -v '^\#' | awk -F\" '{print $$2}')
VERSION := $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)$(VERSION_TAG)

# Append distro flavor, if set
ifneq ($(DISTRO_FLAVOR),)
  VERSION := $(VERSION)-$(DISTRO_FLAVOR)
endif

# BitBake image to build
IMAGE := aclima-core

# Machine to build image for
MACHINE := beaglebone

# C library to use for the toolchain, either "glibc", "musl" or "uclibc"
TCLIBC := glibc

# Detect SDK machine
SDKMACHINE := $(shell uname -m)

# Download Repo, the Google-built repository management tool
REPO_BIN := build/repo
$(REPO_BIN):
	mkdir -p build
	curl https://storage.googleapis.com/git-repo-downloads/repo-1 > $(REPO_BIN)

	chmod a+x $(REPO_BIN)

.PHONY: repo
repo: $(REPO_BIN)

# Repo will pull the manifest from the latest commit of the current branch
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

# Initialize the manifest
REPO_MANIFEST_REF=build/.repo/manifests.git/FETCH_HEAD
$(REPO_MANIFEST_REF): repo default.xml
	@# Make sure repo binary isn't empty
	@REPO_SIZE=$$(du --apparent-size --block-size=1 $(REPO_BIN) | awk 'NR==1{print $$1}'); \
	  if [ "$$REPO_SIZE" = "0" ]; then \
	    echo; \
	    echo "Error: A previous run left an invalid file. Make sure curl is installed:"; \
	    echo "sudo apt-get install curl"; \
	    echo; \
	    echo "Then run the following command:"; \
	    echo "rm $(REPO_BIN)"; \
	    echo; \
	    exit 1; \
	  fi
	cd build && \
	  rm -rf ".repo/manifests" && \
	  python2 repo init --manifest-url .. --manifest-branch $(GIT_BRANCH) && \
	  cp "../default.xml" ".repo/manifests"

.PHONY: init
.PHONY: FORCE
init: $(REPO_MANIFEST_REF) FORCE

# Update the manifest
REPO_MANIFEST=build/.repo/project.list
$(REPO_MANIFEST): init
	cd build; \
	  python2 repo sync --force-sync

# Sync Repo sources
.PHONY: sync
sync: $(REPO_MANIFEST)

# Build the root filesystem
ROOT_FS=build/deploy/$(DISTRO)-$(TCLIBC)/images/$(MACHINE)/$(IMAGE)-$(MACHINE).ext4
$(ROOT_FS): sync
	cd build; \
	  export DISTRO=$(DISTRO); \
	  export MACHINE=$(MACHINE); \
	  export SDKMACHINE=$(SDKMACHINE); \
	  . setup-environment; \
	  bitbake $(IMAGE)
	touch $(ROOT_FS)

.PHONY: build
build: $(ROOT_FS)

# Package the image
TARGET_IMAGE=target/$(DISTRO)-$(IMAGE)-$(VERSION)-$(MACHINE).img.gz
$(TARGET_IMAGE): build
	cd build; \
	  export DISTRO=$(DISTRO); \
	  export MACHINE=$(MACHINE); \
	  export SDKMACHINE=$(SDKMACHINE); \
	  . setup-environment; \
	  cd ..; \
	  export VERSION=$(VERSION); \
	  export TCLIBC=$(TCLIBC); \
	  export IMAGE=$(IMAGE); \
	  ./scripts/copy_image.sh

.PHONY: image
image: $(TARGET_IMAGE)

# Clean BitBake target
.PHONY: clean
clean:
	rm -rf ./build/buildhistory
	rm -rf ./build/deploy
	rm -rf ./build/tmp-*

# Remove ALL files created by make
.PHONY: distclean
distclean:
	rm -rf ./build
