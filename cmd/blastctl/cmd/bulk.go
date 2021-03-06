//  Copyright (c) 2017 Minoru Osuka
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// 		http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package cmd

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/buger/jsonparser"
	"github.com/roscopecoltran/blast/pkg/client"
	"github.com/spf13/cobra"
	"io/ioutil"
	"os"
	"time"
)

type BulkCommandOptions struct {
	server         string
	dialTimeout    int
	requestTimeout int
	batchSize      int32
	request        string
}

var bulkCmdOpts = BulkCommandOptions{
	server:         "localhost:5000",
	dialTimeout:    60000,
	requestTimeout: 60000,
	batchSize:      1000,
	request:        "",
}

var bulkCmd = &cobra.Command{
	Use:   "bulk",
	Short: "puts or deletes the documents in bulk",
	Long:  `The bulk command puts or deletes the documents in bulk.`,
	RunE:  runEBulkCmd,
}

func runEBulkCmd(cmd *cobra.Command, args []string) error {
	// read request
	var data []byte
	var err error
	if cmd.Flag("request").Changed {
		if bulkCmdOpts.request == "-" {
			data, err = ioutil.ReadAll(os.Stdin)
		} else {
			file, err := os.Open(bulkCmdOpts.request)
			if err != nil {
				return err
			}
			defer file.Close()
			data, err = ioutil.ReadAll(file)
			if err != nil {
				return err
			}
		}
	}

	// get batch_size from request
	batchSize, err := jsonparser.GetInt(data, "batch_size")
	if err != nil {
		return err
	}

	// get requests from request
	requestsBytes, _, _, err := jsonparser.Get(data, "requests")
	if err != nil {
		return err
	}
	var requests []map[string]interface{}
	err = json.Unmarshal(requestsBytes, &requests)
	if err != nil {
		return err
	}

	// overwrite batch size by command line option
	if cmd.Flag("batch-size").Changed {
		batchSize = int64(bulkCmdOpts.batchSize)
	}

	// create client config
	cfg := client.Config{
		Server:      bulkCmdOpts.server,
		DialTimeout: time.Duration(bulkCmdOpts.dialTimeout) * time.Millisecond,
		Context:     context.Background(),
	}

	// create client
	c, err := client.NewBlastClient(&cfg)
	if err != nil {
		return err
	}
	defer c.Close()

	// create context
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(bulkCmdOpts.requestTimeout)*time.Millisecond)
	defer cancel()

	// update documents to index in bulk
	resp, _ := c.Index.Bulk(ctx, requests, int32(batchSize))

	// output request
	switch rootCmdOpts.outputFormat {
	case "text":
		fmt.Printf("%v\n", resp)
	case "json":
		output, err := json.MarshalIndent(resp, "", "  ")
		if err != nil {
			return err
		}
		fmt.Printf("%s\n", output)
	default:
		fmt.Printf("%v\n", resp)
	}

	return nil
}

func init() {
	bulkCmd.Flags().SortFlags = false

	bulkCmd.Flags().StringVar(&bulkCmdOpts.server, "server", bulkCmdOpts.server, "server to connect to")
	bulkCmd.Flags().IntVar(&bulkCmdOpts.dialTimeout, "dial-timeout", bulkCmdOpts.dialTimeout, "dial timeout")
	bulkCmd.Flags().IntVar(&bulkCmdOpts.requestTimeout, "request-timeout", bulkCmdOpts.requestTimeout, "request timeout")
	bulkCmd.Flags().Int32Var(&bulkCmdOpts.batchSize, "batch-size", bulkCmdOpts.batchSize, "batch size of bulk request")
	bulkCmd.Flags().StringVar(&bulkCmdOpts.request, "request", bulkCmdOpts.request, "request file")

	RootCmd.AddCommand(bulkCmd)
}
