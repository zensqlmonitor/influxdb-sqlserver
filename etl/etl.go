package etl

import (
	"bytes"
	"database/sql"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"strings"

	_ "github.com/zensqlmonitor/go-mssqldb"
)

type Extracter interface {
	Extract() error
}

type extracter struct {
	connString string
	query      string
	Result     string
}

var _ Extracter = (*extracter)(nil)

func NewExtracter(connString, query string) extracter {
	ext := extracter{}
	ext.connString = connString
	ext.query = query
	return ext
}

func (ext *extracter) Extract() error {
	// deferred opening
	conn, err := sql.Open("mssql", ext.connString)
	if err != nil {
		// Handle error
		return errors.New(err.Error())
	}
	// verify that a connection can be made before making a query
	err = conn.Ping()
	if err != nil {
		// Handle error
		return errors.New(err.Error())
	}
	defer conn.Close()

	// execute query
	rows, err := conn.Query(ext.query)
	if err != nil {
		// Handle error
		return errors.New(err.Error())
	}
	defer rows.Close()

	for rows.Next() {
		var result string
		if err := rows.Scan(&result); err != nil {
			// Handle error
			return errors.New(err.Error())
		}
		// write string
		ext.Result += fmt.Sprintf("%s\n", result)
	}
	if err := rows.Err(); err != nil {
		// Handle error
		return errors.New(err.Error())
	}

	return nil
}

type Loader interface {
	Load() error
}

type loader struct {
	url       string
	database  string
	username  string
	password  string
	precision string
	result    string
}

var _ Loader = (*loader)(nil)

func NewLoader(url, result string) loader {
	loa := loader{}
	loa.url = url
	loa.result = result
	return loa
}

// 2xx: If it's HTTP 204 No Content, success!
//      If it's HTTP 200 OK, InfluxDB understood the request but couldn't complete it.
// 4xx: InfluxDB could not understand the request.
// 5xx: The system is overloaded or significantly impaired
func (loa *loader) Load() error {

	client := &http.Client{}
	req, err := http.NewRequest("POST", loa.url, bytes.NewBufferString(loa.result))
	req.Header.Set("Content-Type", "application/text")
	if len(loa.username) > 0 {
		req.SetBasicAuth(loa.username, loa.password)
	}
	params := req.URL.Query()
	if len(loa.precision) > 0 {
		params.Set("precision", loa.precision)
	}
	req.URL.RawQuery = params.Encode()
	resp, err := client.Do(req)

	if err != nil {
		// Handle error
		return errors.New(err.Error())
	}
	defer resp.Body.Close()

	// read response
	htmlData, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		// Handle error
		return errors.New(err.Error())
	}
	// check for success
	if !strings.Contains(resp.Status, "204") {
		// Handle error
		return errors.New(string(htmlData))
	}
	return nil

}
