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
	AnalysisID  int64  `json:"analysis_id"`
	Directory   string `json:"directory"`
	Bucket      string `json:"bucket"`
	Destination string `json:"destination"`
}

type Output struct {
	ArchivePath string `json:"archive_path"`
	AnalysisID  int64  `json:"analysis_id"`
}

func HandleRequest(ctx context.Context, evt Event) (*Output, error) {

	fmt.Printf("hello world, reading files from %s\n", evt.Directory)

	reader, writer := io.Pipe()

	fmt.Println(listDirectoryContents(evt.Directory))

	opts := archiver.FromDiskOptions{FollowSymlinks: false, ClearAttributes: true}
	files, err := archiver.FilesFromDisk(&opts, map[string]string{
		evt.Directory: "", // fmt.Sprintf("workspaces-archive/%d", evt.AnalysisID),
	})

	//	fmt.Printf("files: %v\n", files)

	if err != nil {
		return nil, err
	}

	n := 0
	for i := range files {
		ext := strings.ToLower(filepath.Ext(files[i].NameInArchive))
		if ext != ".git" && ext != ".csv" {
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
	// fileName := "/mnt/efs/kinetic/.lintr"
	// f, err := os.Open(fileName)
	// if err != nil {
	// 	return "", fmt.Errorf("failed to open file %q, %v", fileName, err)
	// }

	result, err := uploader.UploadWithContext(ctx, &s3manager.UploadInput{
		Bucket: aws.String(evt.Bucket),
		Key:    aws.String(evt.Destination),
		Body:   reader,
	})
	if err != nil {
		return nil, fmt.Errorf("failed to uploadResult fileToUpload, %v", err)
	}

	// Check if an error occurred in the goroutine
	if errGoroutine := <-errChan; errGoroutine != nil {
		return nil, fmt.Errorf("failed to read %s: %s", evt.Directory, errGoroutine.Error())
	}

	output := Output{
		ArchivePath: result.Location,
		AnalysisID:  evt.AnalysisID,
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
