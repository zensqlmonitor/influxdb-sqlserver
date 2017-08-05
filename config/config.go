// Package config provides the influxdb-sqlserver specific configuration options.
package config

import ()

// Defaults for config variables which are not set
const (
	DefaultLogFileName  string = "influxdb-sqlserver.log"
	DefaultModes        string = "file"
	DefaultBufferLen    int    = 10000
	DefaultLevelConsole string = "Trace"
	DefaultLevelFile    string = "Warn"
	DefaultFormatting   bool   = true
	DefaultLogRotate    bool   = true
	DefaultMaxLines     int    = 1000000
	DefaultMaxSizeShift int    = 28
	DefaultDailyRotate  bool   = true
	DefaultMaxDays      int    = 7

	DefaultSqlScriptPath string = "/usr/local/influxdb-sqlserver/sqlscripts/"

	DefaultPollingInterval        int = 15
	DefaultPollingIntervalIfError int = 60

	DefaultInfluxDBUrl       string = "http://localhost:8086"
	DefaultInfluxDBTimeOut   int    = 0
	DefaultInfluxDBDatabase  string = "SQLSERVER"
	DefaultInfluxDBPrecision string = "ms"
)

type TOMLConfig struct {
	InfluxDB influxDB
	Servers  map[string]Server
	Scripts  map[string]*script
	Polling  polling
	Logging  logging
}
type polling struct {
	Interval        int
	IntervalIfError int
}
type influxDB struct {
	Url       string
	Database  string
	Username  string
	Password  string
	Precision string
	TimeOut   int
}
type logging struct {
	Modes        string
	BufferLen    int
	LevelConsole string
	LevelFile    string
	FileName     string
	Formatting   bool
	LogRotate    bool
	MaxLines     int
	MaxSizeShift int
	DailyRotate  bool
	MaxDays      int
}
type Server struct {
	IP       string
	Port     int
	Username string
	Password string
}
type script struct {
	Name     string
	Interval int
}
