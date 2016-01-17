package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/signal"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/zensqlmonitor/influxdb-sqlserver/Godeps/_workspace/src/github.com/BurntSushi/toml"

	cfg "github.com/zensqlmonitor/influxdb-sqlserver/config"
	"github.com/zensqlmonitor/influxdb-sqlserver/etl"
	"github.com/zensqlmonitor/influxdb-sqlserver/log"
)

var wg sync.WaitGroup
var exitChan = make(chan int)

var fConfig = flag.String("config", "influxdb-sqlserver.conf", "the configuration file in TOML format")

type TOMLConfig cfg.TOMLConfig

var config TOMLConfig

type DynMap map[string]interface{}

type Param struct {
	connString      string
	fullFilePath    string
	pollingInterval int
	url             string
	database        string
	username        string
	password        string
	precision       string
}

//
// Listen to System Signals
//
func listenToSystemSignals() {
	signalChan := make(chan os.Signal, 1)
	code := 0

	signal.Notify(signalChan, os.Interrupt)
	signal.Notify(signalChan, os.Kill)
	signal.Notify(signalChan, syscall.SIGTERM)

	select {
	case sig := <-signalChan:
		log.Info("Received signal %s. shutting down", sig)
	case code = <-exitChan:
		switch code {
		case 0:
			log.Info("Shutting down")
		default:
			log.Warn("Shutting down")
		}
	}
	log.Close()
	os.Exit(code)
}

//
// Init logging
//
func (config *TOMLConfig) initLogging() {
	var LogModes []string
	var LogConfigs []DynMap

	// Log Modes
	LogModes = strings.Split(config.Logging.Modes, ",")
	LogConfigs = make([]DynMap, len(LogModes))

	for i, mode := range LogModes {
		mode = strings.TrimSpace(mode)
		//fmt.Println(mode)

		// Log Level
		var levelName string
		if mode == "console" {
			levelName = config.Logging.LevelConsole
		} else {
			levelName = config.Logging.LevelFile
		}

		level, ok := log.LogLevels[levelName]
		if !ok {
			log.Fatal(4, "Unknown log level: %s", levelName)
		}
		// Generate log configuration
		switch mode {
		case "console":
			formatting := config.Logging.Formatting
			LogConfigs[i] = DynMap{
				"level":      level,
				"formatting": formatting,
			}
		case "file":
			LogConfigs[i] = DynMap{
				"level":    level,
				"filename": config.Logging.FileName,
				"rotate":   config.Logging.LogRotate,
				"maxlines": config.Logging.MaxLines,
				"maxsize":  1 << uint(config.Logging.MaxSizeShift),
				"daily":    config.Logging.DailyRotate,
				"maxdays":  config.Logging.MaxDays,
			}
		}
		cfgJsonBytes, _ := json.Marshal(LogConfigs[i])
		log.NewLogger(10000, mode, string(cfgJsonBytes))
	}
}

// Validate adds default value, validates the config data
// and returns an error describing any problems or nil.
func (toml *TOMLConfig) Validate() error {
	// defaults
	if toml.Logging.FileName == "" {
		toml.Logging.FileName = cfg.DefaultLogFileName
	}
	if toml.Logging.Modes == "" {
		toml.Logging.Modes = cfg.DefaultModes
	}
	if toml.Logging.BufferLen == 0 {
		toml.Logging.BufferLen = cfg.DefaultBufferLen
	}
	if toml.Logging.LevelConsole == "" {
		toml.Logging.LevelConsole = cfg.DefaultLevelConsole
	}
	if toml.Logging.LevelFile == "" {
		toml.Logging.LevelFile = cfg.DefaultLevelFile
	}
	if toml.Logging.MaxLines == 0 {
		toml.Logging.MaxLines = cfg.DefaultMaxLines
	}
	if toml.Logging.MaxSizeShift == 0 {
		toml.Logging.MaxSizeShift = cfg.DefaultMaxSizeShift
	}
	if toml.Logging.MaxDays == 0 {
		toml.Logging.MaxDays = cfg.DefaultMaxDays
	}
	if toml.Polling.Interval == 0 {
		toml.Polling.Interval = cfg.DefaultPollingInterval
	}
	if toml.Polling.IntervalIfError == 0 {
		toml.Polling.IntervalIfError = cfg.DefaultPollingIntervalIfError
	}
	if toml.InfluxDB.Url == "" {
		toml.InfluxDB.Url = cfg.DefaultInfluxDBUrl
	}
	if toml.InfluxDB.Database == "" {
		toml.InfluxDB.Database = cfg.DefaultInfluxDBDatabase
	}
	if toml.InfluxDB.Precision == "" {
		toml.InfluxDB.Precision = cfg.DefaultInfluxDBPrecision
	}
	if toml.InfluxDB.TimeOut == 0 {
		toml.InfluxDB.TimeOut = cfg.DefaultInfluxDBTimeOut
	}

	// InfluxDB
	fullUrl := strings.Replace(toml.InfluxDB.Url, "http://", "", -1)

	host, portStr, err := net.SplitHostPort(fullUrl)
	if err != nil {
		return fmt.Errorf("InfluxDB url must be formatted as host:port but "+
			"was '%s' (%v)", toml.InfluxDB.Url, err)
	}
	if len(host) == 0 {
		return fmt.Errorf("InfluxDB url value ('%s') is missing a host",
			toml.InfluxDB.Url)
	}
	port, err := strconv.Atoi(portStr)
	if err != nil {
		return fmt.Errorf("InfluxDB url port value ('%s') must be a number "+
			"(%v)", portStr, err)
	}
	if port < 1 || port > 65535 {
		return fmt.Errorf("InfluxDB url port must be within [1-65535] but "+
			"was '%d'", port)
	}

	// SQL Server
	servers := toml.Servers
	if len(servers) == 0 {
		return fmt.Errorf("You must at least define a SQL Server instance")
	}
	for _, server := range servers {
		if server.IP == "" {
			return fmt.Errorf("SQL Server instance IP is not defined")
		}

		if server.Port < 1 || server.Port > 65535 {
			return fmt.Errorf("InfluxDB url port must be within [1-65535] but "+
				"was '%d'", server.Port)
		}
	}

	// Scripts
	scripts := toml.Scripts
	if len(scripts) == 0 {
		return fmt.Errorf("You must at least define one SQL script")
	}
	for scriptName, script := range scripts {
		if script.Interval < 15 {
			toml.Scripts[scriptName].Interval = 15 // override
		}
	}
	return nil
}

//
// Gather data
//
func (p *Param) gather() {
	var wgi sync.WaitGroup

	for {
		wgi.Add(1)

		go func(p *Param) {
			defer wgi.Done()

			// read script
			sqlscript, err := ioutil.ReadFile(p.fullFilePath)
			if err != nil {
				// Handle error
				log.Error(1, "Error while reading script", err)
			}

			// extract data
			start := time.Now()
			ext := etl.NewExtracter(p.connString, string(sqlscript))
			err = ext.Extract()
			if err != nil {
				// Handle error
				log.Error(1, "Error while executing script", err)
			}
			stringSlice := strings.Split(p.connString, ";")
			log.Trace(fmt.Sprintf("<-- Extract | %v sec | %s,%s | %s | took %s", p.pollingInterval,
				stringSlice[0], strings.Replace(stringSlice[1], "Port=", "", -1), p.fullFilePath,
				time.Since(start)))

			// load data
			start = time.Now()
			loa := etl.NewLoader(fmt.Sprintf("%s/write?db=%s&precision=%s", p.url, p.database, p.precision), ext.Result)
			err = loa.Load()
			if err != nil {
				// Handle error
				log.Error(1, "Error while loading data", err)
			}
			log.Trace(fmt.Sprintf("--> Load    | %v sec | %s,%s | %s | took %s", p.pollingInterval,
				stringSlice[0], strings.Replace(stringSlice[1], "Port=", "", -1), p.fullFilePath,
				time.Since(start)))

		}(p) // end go routine

		//defer log.Info("Sleeping now for %d sec...", p.pollingInterval)
		time.Sleep(time.Duration(p.pollingInterval) * time.Second)
	}

	wgi.Wait()
}

//
// Init
//
func init() {
	runtime.GOMAXPROCS(runtime.NumCPU())
}

//
// Utils
//
func connectionString(server cfg.Server) string {
	return fmt.Sprintf(
		"Server=%s;Port=%v;User Id=%s;Password=%s;app name=influxdb-sqlserver;log=1",
		server.IP, server.Port, server.Username, server.Password)
}

//
// Main
//
func main() {

	// command-line flag parsing
	flag.Parse()

	// config data
	if _, err := toml.DecodeFile(*fConfig, &config); err != nil {
		// Handle error: panic
		panic(err)
	}
	if err := (&config).Validate(); err != nil {
		fmt.Println(err)
		return
	}

	// init global logging
	config.initLogging()

	// listen to System Signals
	go listenToSystemSignals()

	// polling loop
	log.Info("Starting influxdb-sqlserver")
	scripts := config.Scripts

	for _, server := range config.Servers { // foreach server

		// set connString
		connString := connectionString(server)

		for _, script := range scripts { // foreach script

			// test if path exists
			scriptPath := cfg.DefaultSqlScriptPath + script.Name
			scriptInterval := script.Interval

			if _, err := os.Stat(scriptPath); err != nil {
				// Handle error: panic
				log.Error(3, "Script file path does not exist!", err)
				panic(err)
			}

			//  start collect within a go routine
			wg.Add(1) // increment the WaitGroup counter
			p := &Param{connString,
				scriptPath,
				scriptInterval,
				config.InfluxDB.Url,
				config.InfluxDB.Database,
				config.InfluxDB.Username,
				config.InfluxDB.Password,
				config.InfluxDB.Precision}
			go p.gather()

		} // end foreach script
	} // end foreach server

	// Wait for goroutines to complete.
	wg.Wait()
}
