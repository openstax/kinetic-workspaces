package main

import (
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"path/filepath"

	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/mholt/archiver/v4"

	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
)

type Event struct {
	Key            string `json:"key"`
	AnalysisID     int64  `json:"analysis_id"`
	EnclaveApiKey  string `json:"enclave_api_key"`
	AnalysisApiKey string `json:"analysis_api_key"`
	//	SrcDirectory   string `json:"src_directory"`
	Bucket string `json:"bucket"`
	//	Destination string `json:"destination"`
}

func (evt *Event) BucketPath() *string {
	return aws.String(fmt.Sprintf("review/%d/%s/archive.tar.zst", evt.AnalysisID, evt.Key))
}

type Output struct {
	Key            string `json:"key"`
	ArchivePath    string `json:"archive_path"`
	AnalysisID     int64  `json:"analysis_id"`
	EnclaveApiKey  string `json:"enclave_api_key"`
	AnalysisApiKey string `json:"analysis_api_key"`
}

func HandleRequest(ctx context.Context, evt Event) (*Output, error) {

	srcDirectory := fmt.Sprintf("/mnt/efs/editor/%d", evt.AnalysisID)

	fmt.Printf("hello world, reading %s writing to %s\n", srcDirectory, *evt.BucketPath())

	reader, writer := io.Pipe()

	fmt.Println(listDirectoryContents(srcDirectory))

	opts := archiver.FromDiskOptions{FollowSymlinks: false, ClearAttributes: true}
	files, err := archiver.FilesFromDisk(&opts, map[string]string{
		srcDirectory: "archive",
	})

	if err != nil {
		return nil, err
	}

	n := 0
	for i := range files {
		ext := strings.ToLower(filepath.Ext(files[i].NameInArchive))
		if ext != ".git" {
			files[n] = files[i]
			n += 1
		}
	}
	files = files[:n]

	format := archiver.CompressedArchive{
		Compression: archiver.Zstd{},
		Archival:    archiver.Tar{},
	}

	fmt.Println("Creating archive...")

	// Create a channel to communicate errors from the goroutine
	errChan := make(chan error, 1)

	go func() {
		defer writer.Close()
		err = format.Archive(ctx, writer, files)
		if err != nil {
			fmt.Printf("Err writing %s\n", err)
			errChan <- err
		}
		close(errChan)
	}()

	sess := session.Must(session.NewSession())

	uploader := s3manager.NewUploader(sess)

	result, err := uploader.UploadWithContext(ctx, &s3manager.UploadInput{
		Bucket: aws.String(evt.Bucket),
		Key:    evt.BucketPath(),
		Body:   reader,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to uploadResult fileToUpload, %v", err)
	}

	// Check if an error occurred in the goroutine
	if errGoroutine := <-errChan; errGoroutine != nil {
		return nil, fmt.Errorf("failed to read %s: %s", srcDirectory, errGoroutine.Error())
	}

	output := Output{
		Key:            evt.Key,
		ArchivePath:    result.Location,
		AnalysisID:     evt.AnalysisID,
		EnclaveApiKey:  evt.EnclaveApiKey,
		AnalysisApiKey: evt.AnalysisApiKey,
	}

	return &output, nil
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
	// for testing locally
	// out, err := HandleRequest(context.Background(), Event{
	// 	AnalysisID:  1,
	// 	Directory:   "/Users/nas/code/ox/kinetic/frontend", // just some largish files
	// 	Bucket:      "kinetic-workspaces-archive",
	// 	Destination: "review/1/2023-05-01T16:12:35-05:00.zst",
	// })
	// fmt.Printf("out: %s\nerr: %s\n", out, err)
	// if false {
	lambda.Start(HandleRequest)
	// }
}
