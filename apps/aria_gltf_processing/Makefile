# SPDX-License-Identifier: MIT
# Copyright (c) 2025-present K. S. Ernest (iFire) Lee

.PHONY: all clean

# Get Elixir include and lib paths
ERL_EI_INCLUDE_DIR ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/usr/include"])])' -s init stop -noshell)
ERL_EI_LIBDIR ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/usr/lib"])])' -s init stop -noshell)

# Build directory
BUILD_DIR = c_build

# Source files
C_SRC = c_src/ufbx_nif.c
UFBX_SRC = thirdparty/ufbx/ufbx.c
C_OBJECTS = $(BUILD_DIR)/ufbx_nif.o $(BUILD_DIR)/ufbx.o

# Compiler flags
CFLAGS = -fPIC -std=c99 -Wall -Wextra
CFLAGS += -I$(ERL_EI_INCLUDE_DIR)
CFLAGS += -Ithirdparty/ufbx

# Linker flags (use -bundle for macOS, -shared for Linux)
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    LDFLAGS = -bundle -undefined dynamic_lookup
else
    LDFLAGS = -shared
endif

# Output library
PRIV_DIR = priv
NIF_SO = $(PRIV_DIR)/ufbx_nif.so

all: $(NIF_SO)

$(NIF_SO): $(C_OBJECTS) | $(PRIV_DIR)
	@mkdir -p $(PRIV_DIR)
	$(CC) $(LDFLAGS) -o $@ $(C_OBJECTS)

$(BUILD_DIR)/ufbx_nif.o: $(C_SRC) | $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c -o $@ $< -fno-common

$(BUILD_DIR)/ufbx.o: $(UFBX_SRC) | $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c -o $@ $< -fno-common

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(PRIV_DIR):
	@mkdir -p $(PRIV_DIR)

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(PRIV_DIR)

