package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/aws/aws-sdk-go/aws/session"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/klauspost/compress/zstd"
)

type Event struct {
	Directory   string `json:"directory"`
	Bucket      string `json:"bucket"`
	Destination string `json:"destination"`
}

// Compress input to output.
func Compress(in io.Reader, out io.Writer) error {
	enc, err := zstd.NewWriter(out)
	if err != nil {
		return err
	}
	_, err = io.Copy(enc, in)
	if err != nil {
		enc.Close()
		return err
	}
	return enc.Close()
}

func HandleRequest(ctx context.Context, evt Event) (string, error) {

	return listDirectoryContents("/tmp"), nil

	sess := session.Must(session.NewSession())

	uploader := s3manager.NewUploader(sess)

	f, err := os.Open("main.go")
	if err != nil {
		return "", fmt.Errorf("failed to open directory %q, %v", evt.Directory, err)
	}

	defer func(f *os.File) {
		err := f.Close()
		if err != nil {
			fmt.Errorf("error closing fileToUpload: %v", err)
		}
	}(f)

	// Upload the file to S3.
	result, err := uploader.Upload(&s3manager.UploadInput{
		Bucket: aws.String(evt.Bucket),
		Key:    aws.String(evt.Destination),
		Body:   f,
	})
	if err != nil {
		return "", fmt.Errorf("failed to uploadResult fileToUpload, %v", err)
	}

	return json.Marshal(result), nil
}

func listDirectoryContents(directoryPath string) string {
	files, err := ioutil.ReadDir(directoryPath)
	if err != nil {
		log.Fatal(err)
	}

	var output strings.Builder
	output.WriteString(fmt.Sprintf("Listing contents of directory: %s\n", directoryPath))
	for _, file := range files {
		output.WriteString(file.Name())
		output.WriteString("\n")
	}

	return output.String()
}

func main() {

	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	lambda.Start(HandleRequest)
}
