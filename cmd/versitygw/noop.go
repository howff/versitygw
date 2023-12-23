// Copyright 2023 Versity Software
// This file is licensed under the Apache License, Version 2.0
// (the "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

package main

import (
	"fmt"

	"github.com/urfave/cli/v2"
	"github.com/versity/versitygw/backend/noop"
)

func noopCommand() *cli.Command {
	return &cli.Command{
		Name:        "noop",
		Usage:       "noop storage backend",
		Description: `This is a /dev/null backend for testing.`,
		Action:      runNoOp,
	}
}

func runNoOp(ctx *cli.Context) error {
	be, err := noop.New()
	if err != nil {
		return fmt.Errorf("init noop backend: %w", err)
	}
	return runGateway(ctx.Context, be)
}
