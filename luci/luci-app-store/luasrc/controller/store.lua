module("luci.controller.store", package.seeall)

local myopkg = "is-opkg"
local opkg = "opkg"

function index()
    local action
    entry({"admin", "store"}, alias("admin", "store", "token"))
    entry({"admin", "store", "token"}, call("store_token"))
    for _, action in ipairs({"update", "install", "upgrade", "remove"}) do
        entry({"admin", "store", action}, post("store_action", {action = action}))
    end
    for _, action in ipairs({"status"}) do
        entry({"admin", "store", action}, call("store_action", {action = action}))
    end
end

-- Internal action function
local function _action(exe, cmd, ...)
    local os   = require "os"
    local io   = require "io"
    local fs   = require "nixio.fs"
    
	local pkg = ""
	for k, v in pairs({...}) do
		pkg = pkg .. " '" .. v:gsub("'", "") .. "'"
	end

	local c = "%s %s %s >/tmp/opkg.stdout 2>/tmp/opkg.stderr" %{ exe, cmd, pkg }
	local r = os.execute(c)
	local e = fs.readfile("/tmp/opkg.stderr")
	local o = fs.readfile("/tmp/opkg.stdout")

	fs.unlink("/tmp/opkg.stderr")
	fs.unlink("/tmp/opkg.stdout")

	return r, o or "", e or ""
end

function store_action(param)
    local code, out, err
    local sys  = require "luci.sys"
    local action = param.action or ""
    local pkgs = luci.http.formvalue("packages") or {}

    if action == "" then
        luci.http.status(400, "Bad Request")
        return nil
    end

    if not (type(pkgs) == "table") then
        pkgs = {pkgs}
    end
    if action == "update" or action == "install" or action == "upgrade" then
        code, out, err = _action(myopkg, action, unpack(pkgs))
    else
        code, out, err = _action(opkg, action, unpack(pkgs))
    end

    local status = {
        code = code,
        stdout = out,
        stderr = err
    }

    luci.http.prepare_content("application/json")
    luci.http.write_json(status)
end

function store_token()
    luci.http.prepare_content("application/json")
    require "luci.template".render_string("{\"token\":\"<%=token%>\"}")
end
