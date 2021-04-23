module("luci.controller.store", package.seeall)

local myopkg = "is-opkg"
local opkg = "opkg"

function index()
    local function store_api(action, onlypost)
        local e = entry({"admin", "store", action}, onlypost and post("store_action", {action = action}) or call("store_action", {action = action}))
        e.dependent = false -- 父节点不是必须的
        e.leaf = true -- 没有子节点
    end

    local action

    entry({"admin", "store"}, alias("admin", "store", "token"))
    entry({"admin", "store", "token"}, call("store_token"))
    for _, action in ipairs({"update", "install", "upgrade", "remove"}) do
        store_api(action, true)
    end
    for _, action in ipairs({"status"}) do
        store_api(action, false)
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
    local code, out, err, ret
    local ipkg = require "luci.model.ipkg"
    local action = param.action or ""

    if action == "status" then
        ret = {
            code = 0,
            data = ipkg.status(luci.http.formvalue("package"))
        }
    else
        local pkgs = luci.http.formvalue("packages") or {}

        if type(pkgs) ~= "table" then
            pkgs = {pkgs}
        end
        if action == "update" or action == "install" or action == "upgrade" then
            code, out, err = _action(myopkg, action, unpack(pkgs))
        else
            code, out, err = _action(opkg, action, unpack(pkgs))
        end

        ret = {
            code = code,
            stdout = out,
            stderr = err
        }
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json(ret)
end

function store_token()
    luci.http.prepare_content("application/json")
    require "luci.template".render_string("{\"token\":\"<%=token%>\"}")
end
