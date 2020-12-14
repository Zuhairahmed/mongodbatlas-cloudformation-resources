package util

import (
	"github.com/Sectorbob/mlab-ns2/gae/ns/digest"
    "go.mongodb.org/atlas/mongodbatlas"
    "strings"
    "log"
)

const (
	Version = "beta"
)

// This takes either "us-east-1" or "US_EAST_1"
// and returns "US_EAST_1" -- i.e. a valida Atlas region
func EnsureAtlasRegion(region string) string {
    r := strings.ToUpper(strings.Replace(string(region),"-","_",-1))
    return r
}

func CreateMongoDBClient(publicKey, privateKey string) (*mongodbatlas.Client, error) {
	// setup a transport to handle digest
    log.Printf("CreateMongoDBClient--- publicKey:%s", publicKey)
	transport := digest.NewTransport(publicKey, privateKey)

	// initialize the client
	client, err := transport.Client()
	if err != nil {
		return nil, err
	}

	//Initialize the MongoDB Atlas API Client.
    atlas := mongodbatlas.NewClient(client)
    atlas.UserAgent = "mongodbatlas-cloudformation-resources/" + Version
	return atlas, nil
}
