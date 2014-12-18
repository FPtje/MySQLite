local bit = bit
local debug = debug
local error = error
local ErrorNoHalt = ErrorNoHalt
local hook = hook
local include = include
local pairs = pairs
local require = require
local sql = sql
local string = string
local table = table
local timer = timer
local tostring = tostring
local GAMEMODE = GM or GAMEMODE
local mysqlOO
local TMySQL
local _G = _G

local MySQLite_config = MySQLite_config or RP_MySQLConfig or FPP_MySQLConfig

if MySQLite_config.EnableMySQL then
    moo, tmsql = file.Exists("bin/gmsv_mysqloo_*.dll", "LUA"), file.Exists("bin/gmsv_tmysql4_*.dll", "LUA")

    if not moo and not tmsql then
        error("Could not find a suitable MySQL module. Supported modules are MySQLOO and tmysql4.")
    end

    require(moo and "mysqloo" or "tmysql4")

    mysqlOO = mysqloo
    TMySQL = tmysql
end

module("MySQLite")

function initialize()
	if not MySQLite_config then
		ErrorNoHalt("Warning: No MySQL config!")
	end

    MySQLite_config = MySQLite_config or {}

	if MySQLite_config.EnableMySQL then
		timer.Simple(1, function()
			connectToMySQL(MySQLite_config.Host, MySQLite_config.Username, MySQLite_config.Password, MySQLite_config.Database_name, MySQLite_config.Database_port)
		end)
	else
		timer.Simple(0, function()
			GAMEMODE.DatabaseInitialized = GAMEMODE.DatabaseInitialized or function() end
			hook.Call("DatabaseInitialized", GAMEMODE)
		end)
	end
end

local CONNECTED_TO_MYSQL = false
local databaseObject = nil

local queuedQueries
local cachedQueries

function isMySQL()
	return CONNECTED_TO_MYSQL
end

function begin()
	if not CONNECTED_TO_MYSQL then
		sql.Begin()
	else
		if queuedQueries then
			debug.Trace()
			error("Transaction ongoing!")
		end
		queuedQueries = {}
	end
end

function commit(onFinished)
	if not CONNECTED_TO_MYSQL then
		sql.Commit()
		if onFinished then onFinished() end
		return
	end

	if not queuedQueries then
		error("No queued queries! Call begin() first!")
	end

	if #queuedQueries == 0 then
		queuedQueries = nil
		return
	end

	-- Copy the table so other scripts can create their own queue
	local queue = table.Copy(queuedQueries)
	queuedQueries = nil

	-- Handle queued queries in order
	local queuePos = 0
	local call

	-- Recursion invariant: queuePos > 0 and queue[queuePos] <= #queue
	call = function(...)
		queuePos = queuePos + 1

		if queue[queuePos].callback then
			queue[queuePos].callback(...)
		end

		-- Base case, end of the queue
		if queuePos + 1 > #queue then
			if onFinished then onFinished() end -- All queries have finished
			return
		end

		-- Recursion
		local nextQuery = queue[queuePos + 1]
		query(nextQuery.query, call, nextQuery.onError)
	end

	query(queue[1].query, call, queue[1].onError)
end

function queueQuery(sqlText, callback, errorCallback)
	if CONNECTED_TO_MYSQL then
		table.insert(queuedQueries, {query = sqlText, callback = callback, onError = errorCallback})
		return
	end
	-- SQLite is instantaneous, simply running the query is equal to queueing it
	query(sqlText, callback, errorCallback)
end

local function msOOQuery(sqlText, callback, errorCallback, queryValue)
    local query = databaseObject:query(sqlText)
    local data
    query.onData = function(Q, D)
        data = data or {}
        data[#data + 1] = D
    end

    query.onError = function(Q, E)
        if (databaseObject:status() == mysqlOO.DATABASE_NOT_CONNECTED) then
            table.insert(cachedQueries, {sqlText, callback, queryValue})
            return
        end

        if errorCallback then
            errorCallback()
        end

        ErrorNoHalt(E .. " (" .. sqlText .. ")\n")
    end

    query.onSuccess = function()
        local res = queryValue and data and data[1] and table.GetFirstValue(data[1]) or not queryValue and data or nil
        if callback then callback(res, query:lastInsert()) end
    end
    query:start()
end

local function tmsqlQuery(sqlText, callback, errorCallback, queryValue)
    local call = function(res, succeed, err)
        if not succeed then error(err .. " (" .. sqlText .. ")") end

        if #res == 0 then res = nil end -- compatibility with other backends
        if queryValue and callback then return callback(res and res[1] and res[1][1] or nil) end
        if callback then callback(res, err) end -- err is last inserted row on succeed
    end

    -- We don't want column names when asking for a value
    local flags = bit.bor(queryValue and 0 or _G.QUERY_FLAG_ASSOC, _G.QUERY_FLAG_LASTID)
    databaseObject:Query(sqlText, call, flags)
end

local function SQLiteQuery(sqlText, callback, errorCallback, queryValue)
    local lastError = sql.LastError()
    local Result = queryValue and sql.QueryValue(sqlText) or sql.Query(sqlText)

    if sql.LastError() and sql.LastError() ~= lastError then
        error("SQLite error: " .. sql.LastError())
    end

    if callback then callback(Result) end
    return Result
end

function query(sqlText, callback, errorCallback)
	local qFunc = (CONNECTED_TO_MYSQL and
            mysqlOO and msOOQuery or
            TMySQL and tmsqlQuery) or
        SQLiteQuery
    return qFunc(sqlText, callback, errorCallback, false)
end

function queryValue(sqlText, callback, errorCallback)
    local qFunc = (CONNECTED_TO_MYSQL and
            mysqlOO and msOOQuery or
            TMySQL and tmsqlQuery) or
        SQLiteQuery
    return qFunc(sqlText, callback, errorCallback, true)
end

local function onConnected()
    CONNECTED_TO_MYSQL = true

    -- Run the queries that were called before the connection was made
    for _, v in pairs(cachedQueries or {}) do
        if v[3] then
            queryValue(v[1], v[2])
        else
            query(v[1], v[2])
        end
    end
    cachedQueries = {}

    hook.Call("DatabaseInitialized", GAMEMODE.DatabaseInitialized and GAMEMODE or nil)
end

local function msOOConnect(host, username, password, database_name, database_port)
    databaseObject = mysqlOO.connect(host, username, password, database_name, database_port)

    if timer.Exists("darkrp_check_mysql_status") then timer.Destroy("darkrp_check_mysql_status") end

    databaseObject.onConnectionFailed = function(_, msg)
        error("Connection failed! " .. tostring(msg) ..  "\n")
    end

    databaseObject.onConnected = function()
        timer.Create("darkrp_check_mysql_status", 60, 0, function()
            if (databaseObject and databaseObject:status() == mysqlOO.DATABASE_NOT_CONNECTED) then
                connectToMySQL(MySQLite_config.Host, MySQLite_config.Username, MySQLite_config.Password, MySQLite_config.Database_name, MySQLite_config.Database_port)
            end
        end)

        onConnected()
    end

    databaseObject:connect()
end

local function tmsqlConnect(host, username, password, database_name, database_port)
    local db, err = TMySQL.initialize(host, username, password, database_name, database_port)
    if err then error("Connection failed! " .. err ..  "\n") end

    databaseObject = db
    onConnected()
end

connectToMySQL = mysqlOO and msOOConnect or TMySQL and tmsqlConnect or function() end

function SQLStr(str)
    local escape =
        not CONNECTED_TO_MYSQL and sql.SQLStr or
        mysqlOO                and function(str) return "\"" .. databaseObject:escape(tostring(str)) .. "\"" end or
        TMySQL                 and function(str) return "\"" .. TMySQL.escape(tostring(str))         .. "\"" end

    return escape(str)
end

function tableExists(tbl, callback, errorCallback)
	if not CONNECTED_TO_MYSQL then
		local exists = sql.TableExists(tbl)
		callback(exists)

		return exists
	end

	queryValue(string.format("SHOW TABLES LIKE %s", SQLStr(tbl)), function(v)
		callback(v ~= nil)
	end, errorCallback)
end
