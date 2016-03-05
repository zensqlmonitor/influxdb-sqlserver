[Twitter](https://twitter.com/zensqlmonitor) |
[Email](mailto:sqlzen@hotmail.com)

# influxdb-sqlserver
Collect Microsoft SQL Server metrics, send to InfluxDB and visualize with Grafana

![influxdb-grafana](https://cloud.githubusercontent.com/assets/16494280/13547132/aca6b6ca-e2c5-11e5-9f97-d6ff90918daa.png)


## Getting Started

- InfluxDB: 
	- [Install InfluxDB](https://influxdb.com/docs/v0.9/introduction/installation.html)
	- [Create database SQLSERVER](https://influxdb.com/docs/v0.9/introduction/getting_started.html) <br />
- Grafana:
	- [Install Grafana](http://docs.grafana.org/installation/)
	- Import dashboard from file provided in the [repository](https://github.com/zensqlmonitor/influxdb-sqlserver/tree/master/grafana) <br />
- influxdb-sqlserver:
	- [Install GO](https://golang.org/doc/install)
	- [Setup you GOPATH](https://golang.org/doc/code.html#GOPATH)
	- Run ``` go get github.com/zensqlmonitor/influxdb-sqlserver ```
	- Edit the configuration to match your needs  <br />
- SQL Server:
	- Create a login - with a strong password - in every SQL Server instance you want to monitor:  <br />
	```SQL 
	USE master; 
	GO
	CREATE LOGIN [linuxuser] WITH PASSWORD = N'mystrongpassword';
	GO
	GRANT VIEW SERVER STATE TO [linuxuser]; 
	GO
	GRANT VIEW ANY DEFINITION TO [linuxuser]; 
	GO
	```
	
### How to use GO code

- Run in background: ``` go run influxdb-sqlserver.go & ```
- Build in the current directory: ``` go build influxdb-sqlserver.go ```
- Install in $GOPATH/bin: ``` go install influxdb-sqlserver.go ```

### Dependencies

- Go 1.5
- Microsoft SQL server driver (https://github.com/denisenkom/go-mssqldb)
- TOML parser (https://github.com/BurntSushi/toml)

### Command-line flags
 ``` 
-config (string) = the configuration filepath in toml format (default="influxdb-sqlserver.conf")
-h = usage
 ``` 
 
## T-SQL Scripts provided
Scripts provided are lightweight and use Dynamic Management Views supplied by SQL Server

- getperfcounters.sql: 1000+ metrics from sys.dm_os_performance_counters
- getperfmetrics.sql: some special performance metrics
- getwaitstatscat.sql: list of wait tasks categorized from sys.dm_os_wait_stats
- getmemoryclerksplit.sql: memory breakdown from sys.dm_os_memory_clerks
- getmemory.sql: available and used memory from sys.dm_os_sys_memory
- getdatabasesizetrend.sql: database size trend, datafile and logfile from sys.dm_io_virtual_file_stats
- getdatabaseio.sql: database I/O from sys.dm_io_virtual_file_stats
- getcpu.sql: cpu usage from sys.dm_os_ring_buffers 


##### Note

influxdb-sqlserver uses InfluxDB line protocol. If you add a sql query you have to return one column formatted with this protocol.
For more details, see scripts provided in the repository and the InfluxDB [documentation](https://influxdb.com/docs/v0.9/write_protocols/line.html)



## License

MIT-LICENSE. See LICENSE file provided in the repository for details

