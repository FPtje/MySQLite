#MySQLite - Abstraction mechanism for SQLite and MySQL

###Why use this?
* Easy to use interface for MySQL
* No need to modify code when switching between SQLite and MySQL
* Queued queries: execute a bunch of queries in order an run the callback when all queries are done
    License: LGPL V2.1 (read here: https://www.gnu.org/licenses/lgpl-2.1.html)
    
###Supported MySQL modules:
* MySQLOO
* tmysql4

**Note**: When both MySQLOO and tmysql4 modules are installed, MySQLOO is used by default.

##Documentation

```lua
MySQLite.initialize({
  EnableMySQL = true or false,               -- set to true to use MySQL, false for SQLite
  Host        = string,                    -- database hostname
  Username    = string,                    -- database username
  Password    = string or nil,             -- database password (keep away from clients!), can be nil for users without passwords (not recommended)
  Database_name = string,                  -- name of the database
  Preferred_module = "mysqloo" or "tmysql4", -- Preferred module, case sensitive, must be either "mysqloo" or "tmysql4"
  MultiStatements = true or false            -- Only available in tmysql4: allow multiple SQL statements per query
})
```

###Utility functions

```lua
MySQLite.isMySQL() -- returns true or false
--Use this when the query syntax between SQLite and MySQL differs (example: AUTOINCREMENT vs AUTO_INCREMENT)
--Returns whether MySQLite is set up to use MySQL. True for MySQL, false for SQLite.

MySQLite.SQLStr(string) -- returns string
--Escapes the string and puts it in quotes.
--It uses the escaping method of the module that is currently being used.

MySQLite.tableExists(
  string   -- the table's name
  function -- callback
  function -- errorCallback
) -- returns nothing
function callback(
  boolean -- result
)
-- result is a boolean indicating whether the table exists.
function errorCallback(
  same format as MySQLite.query
)
```

###Running queries

```lua
MySQLite.query(
  string   -- SQL query
  function -- callback
  function -- errorCallback
) -- returns nothing
-- Runs a query. Calls the callback parameter when finished, calls errorCallback when an error occurs.
function callback(
  table  -- result
  number -- lastInsert
)
-- result is the table with results (nil when there are no results or when the result list is empty)
-- lastInsert is the row number of the last inserted value (use with AUTOINCREMENT)
-- Note: lastInsert is NOT supported when using SQLite.
function errorCallback(
  string -- error
  string -- query
)
-- error is the error given by the database module.
-- query is the query that triggered the error.
-- Return true to suppress the error!

MySQlite.queryValue(
  string   -- SQL query
  function -- callback
  function -- errorCallback
) -- returns nothing
-- Runs a query and returns the first value it comes across.
function callback(
  any -- result
)
-- where the result is either a string or a number, depending on the requested database field.
function errorCallback(
  same format as MySQLite.query
)
```

###Transactions

```lua
MySQLite.begin() -- returns nothing
-- Starts a transaction. Use in combination with MySQLite.queueQuery and MySQLite.commit.

MySQLite.queueQuery(
  string   -- SQL query
  function -- callback
  function -- errorCallback
)
-- Queues a query in the transaction. Note: a transaction must be started with MySQLite.begin() for this to work.
-- The callback will be called when this specific query has been executed successfully.
-- The errorCallback function will be called when an error occurs in this specific query.
function callback(
  same format as MySQLite.query
)
function errorCallback(
  same format as MySQLite.query
)

MySQLite.commit(
  function -- onFinished
) -- returns nothing
-- Commits a transaction and calls onFinished when EVERY queued query has finished.
-- onFinished is NOT called when an error occurs in one of the queued queries.
-- onFinished is called without arguments.
```

###Hooks

```lua
DatabaseInitialized( no arguments )
-- Called when a successful connection to the database has been made.
```

#Text-only README

```
--[[
    MySQLite - Abstraction mechanism for SQLite and MySQL

    Why use this?
        - Easy to use interface for MySQL
        - No need to modify code when switching between SQLite and MySQL
        - Queued queries: execute a bunch of queries in order an run the callback when all queries are done

    License: LGPL V2.1 (read here: https://www.gnu.org/licenses/lgpl-2.1.html)

    Supported MySQL modules:
    - MySQLOO
    - tmysql4

    Note: When both MySQLOO and tmysql4 modules are installed, MySQLOO is used by default.

    /*---------------------------------------------------------------------------
    Documentation
    ---------------------------------------------------------------------------*/

    MySQLite.initialize([config :: table]) :: No value
        Initialize MySQLite. Loads the config from either the config parameter OR the MySQLite_config global.
        This loads the module (if necessary) and connects to the MySQL database (if set up).
        The config must have this layout:
            {
                EnableMySQL      :: Bool   - set to true to use MySQL, false for SQLite
                Host             :: String - database hostname
                Username         :: String - database username
                Password         :: String - database password (keep away from clients!)
                Database_name    :: String - name of the database
                Database_port    :: Number - connection port (3306 by default)
                Preferred_module :: String - Preferred module, case sensitive, must be either "mysqloo" or "tmysql4"
                MultiStatements  :: Bool   - Only available in tmysql4: allow multiple SQL statements per query
            }

    ----------------------------- Utility functions -----------------------------
    MySQLite.isMySQL() :: Bool
        Returns whether MySQLite is set up to use MySQL. True for MySQL, false for SQLite.
        Use this when the query syntax between SQLite and MySQL differs (example: AUTOINCREMENT vs AUTO_INCREMENT)

    MySQLite.SQLStr(str :: String) :: String
        Escapes the string and puts it in quotes.
        It uses the escaping method of the module that is currently being used.

    MySQLite.tableExists(tbl :: String, callback :: function, errorCallback :: function)
        Checks whether table tbl exists.

        callback format: function(res :: Bool)
            res is a boolean indicating whether the table exists.

        The errorCallback format is the same as in MySQLite.query.

    ----------------------------- Running queries -----------------------------
    MySQLite.query(sqlText :: String, callback :: function, errorCallback :: function) :: No value
        Runs a query. Calls the callback parameter when finished, calls errorCallback when an error occurs.

        callback format:
            function(result :: table, lastInsert :: number)
            Result is the table with results (nil when there are no results or when the result list is empty)
            lastInsert is the row number of the last inserted value (use with AUTOINCREMENT)

            Note: lastInsert is NOT supported when using SQLite.

        errorCallback format:
            function(error :: String, query :: String) :: Bool
            error is the error given by the database module.
            query is the query that triggered the error.

            Return true to suppress the error!

    MySQLite.queryValue(sqlText :: String, callback :: function, errorCallback :: function) :: No value
        Runs a query and returns the first value it comes across.

        callback format:
            function(result :: any)
                where the result is either a string or a number, depending on the requested database field.

        The errorCallback format is the same as in MySQLite.query.

    ----------------------------- Transactions -----------------------------
    MySQLite.begin() :: No value
        Starts a transaction. Use in combination with MySQLite.queueQuery and MySQLite.commit.

    MySQLite.queueQuery(sqlText :: String, callback :: function, errorCallback :: function) :: No value
        Queues a query in the transaction. Note: a transaction must be started with MySQLite.begin() for this to work.
        The callback will be called when this specific query has been executed successfully.
        The errorCallback function will be called when an error occurs in this specific query.

        See MySQLite.query for the callback and errorCallback format.

    MySQLite.commit(onFinished)
        Commits a transaction and calls onFinished when EVERY queued query has finished.
        onFinished is NOT called when an error occurs in one of the queued queries.

        onFinished is called without arguments.

    ----------------------------- Hooks -----------------------------
    DatabaseInitialized
        Called when a successful connection to the database has been made.
]]
```
