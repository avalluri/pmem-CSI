/*
Copyright 2021 Intel Corporation.

SPDX-License-Identifier: Apache-2.0
*/

// Package testconfig reads config strings from test-config.sh or the environment.
package testconfig

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
)

// Get returns the test config value, an empty string if not set, or an error.
func Get(name string) (string, error) {
	root := os.Getenv("REPO_ROOT")
	if root == "" {
		// The current directory may or may not work as fallback.
		root = "."
	}
	config := fmt.Sprintf("%s/test/test-config.sh", root)
	cmd := exec.Command("/bin/sh", "-c", fmt.Sprintf(`. '%s' && echo "$%s"`, config, name))
	cmd.Dir = root
	value, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("read %s from %s: %v (%s)", name, config, err, string(value))
	}
	return strings.TrimRight(string(value), "\n"), nil
}

// GetOrFail will panic when Get returns an error.
func GetOrFail(name string) string {
	value, err := Get(name)
	if err != nil {
		panic(err)
	}
	return value
}

// GetNodeLabelOrFail is a convenience function which returns TEST_PMEM_NODE_LABEL as string pair.
func GetNodeLabelOrFail() (name, value string) {
	nodeLabel := GetOrFail("TEST_PMEM_NODE_LABEL")
	parts := strings.SplitN(nodeLabel, "=", 2)
	if len(parts) < 2 {
		panic(fmt.Sprintf("expected label=value: TEST_PMEM_NODE_LABEL=%q", nodeLabel))
	}
	return parts[0], parts[1]
}
