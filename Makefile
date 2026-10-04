# Sivm Benchmarks project
# Copyright 2021 The EVM Benchmarks Authors.
# SPDX-License-Identifier: Apache-2.0

# go-sila source of the sivm tool
GO_SILA_REPO := https://github.com/sila-chain/go-sila
GO_SILA_REF := sila/go-sila-v1.17.7-sync-20261001

# Retesteth source
RETESTETH_REPO := https://github.com/ethereum/retesteth
RETESTETH_REF := v0.2.2-merge

# retesteth sources whose built-in "London" fork name is set to SilaLondon for
# this generation build: the 1559 checks and the chain params fork progression.
RETESTETH_SILA_FILES := retesteth/session/ToolBackend/ToolChain.cpp retesteth/testStructures/PrepareChainParams.cpp

# Directory for tools
BIN_DIR := bin

# Directory with benchmark source files
SRC_DIR := src

# Directory for benchmark output files (JSON State Tests)
OUT_DIR := benchmarks

# Place for intermediary files
TMP_DIR := tmp

# Directory with the retesteth config (t8ntool client running sivm).
RETESTETH_CONFIG_DIR := retesteth-config

# go-sila sivm tool for t8n processing, can be built with `make bin/sivm`.
SIVM := ${BIN_DIR}/sivm

# retesteth tool, can be built with `make bin/retesteth`.
RETESTETH := ${BIN_DIR}/retesteth


sources := $(wildcard src/*/*.yml)
outputs := $(sources:${SRC_DIR}/%.yml=${OUT_DIR}/%.json)

# Do not remove any intermediate files.
# Make considers %Filler.yml intermediate files, but we want to keep them for inspection.
.SECONDARY:

all: ${outputs}

# Generate the State Test fillers out of benchmark source files.
${TMP_DIR}/%Filler.yml: ${SRC_DIR}/%.yml
	mkdir -p $(dir $@)
	./sivmbench.py build-source $< -o $@

# Add local bin dir to PATH so the sivm tool can be found by retesteth
export PATH := $(BIN_DIR):$(PATH)

# Generate the State Tests for benchmarks using previously generated fillers.
${OUT_DIR}/%.json: ${TMP_DIR}/%Filler.yml
	${RETESTETH} -t GeneralStateTests -- --datadir ${RETESTETH_CONFIG_DIR} --testpath . --filltests --forceupdate --clients t8ntool --testfile $< --outfile $@

clean:
	rm -rf ${TMP_DIR}
	find ${OUT_DIR} -name '*.json' -delete

# Build the retesteth tool from source.
${RETESTETH}:
	rm -rf ${TMP_DIR}/retesteth
	git clone --depth 1 -b ${RETESTETH_REF} ${RETESTETH_REPO} ${TMP_DIR}/retesteth
	cd ${TMP_DIR}/retesteth && for f in ${RETESTETH_SILA_FILES}; do \
		grep -q '"London"' $$f && sed -i 's/"London"/"SilaLondon"/g' $$f || exit 1; \
	done
	cd ${TMP_DIR}/retesteth && git --no-pager diff
	@echo 'Remaining "London" literals in retesteth (inventory):'
	-cd ${TMP_DIR}/retesteth && git --no-pager grep -n '"London"' -- retesteth
	cmake -S ${TMP_DIR}/retesteth -B ${TMP_DIR}/retesteth/build -DCMAKE_BUILD_TYPE=Release
	cmake --build ${TMP_DIR}/retesteth/build -j 4
	mkdir -p $(dir $@)
	cp ${TMP_DIR}/retesteth/build/retesteth/retesteth $@

# Build the go-sila sivm tool from source.
${SIVM}:
	rm -rf ${TMP_DIR}/go-sila
	git clone --depth 1 -b ${GO_SILA_REF} ${GO_SILA_REPO} ${TMP_DIR}/go-sila
	cd ${TMP_DIR}/go-sila && go build -o $(abspath $@) ./cmd/sivm
