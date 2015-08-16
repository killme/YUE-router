--[[
    Unit tests for yue-router.init

    @internal
]]

local process = require "luvit.process"
require "yue-test"

local router = require "yue-router"

local route = router.Route:new({
    method = { "POST", "DELETE" }
})

local request = {
    host = "test.local",
    method = "POST",
    path = "/hello/world"
}

assertEquals(route.matchMethods, { POST = true, DELETE = true })
assertEquals(route.matchHosts, { "*" })
assertEquals(route.matchPaths, { })
assertEquals({route:match(request)}, {false, {}})

route.parameters = { a = "hello world", b = {"TEST"} }

assertEquals({route:match(request)}, {false, { a = "hello world", b = {"TEST"} }})

route.parameters.b = nil

route.matchPaths["/hello/world"] = true

assertEquals({route:match(request)}, {true, { a = "hello world" }})

local regexRoute = router.RegexRoute:new({
    method = { "POST", "DELETE" },
    pathPatterns = {
        "/user/{uid:[0-9]*}"
    }
})

request.path = "/user/10"

local result, params = regexRoute:match(request)
assertEquals(result, true)
assertEquals(params.uid, "10")

regexRoute.matchMethods["POST"] = nil
local result, params = regexRoute:match(request)
assertEquals(result, false)
assertEquals(params, {})

request.path = "/user/a"
local result, params = regexRoute:match(request)
assertEquals(result, false)
assertEquals(params, {})

local result = pcall(function() router.RegexRoute:new({ pathPatterns = { "/user/{_a:.*}" }}) end)
assertEquals(result, false)

assertEquals(router.RegexRoute:new({ pathPatterns = { "/a*" }}).matchPatterns, {{"/a%*", {}}})

local r = router.Router:new()
r:addRoute(route)
r:addRoute(regexRoute)
assertEquals(r.routes, {route, regexRoute})
r:removeRoute(route)
assertEquals(r.routes, {regexRoute})
r:addRoute(route)
assertEquals(r.routes, {regexRoute, route})

regexRoute.parameters._action = "Controller:regexRoute"
route.parameters._action = "Controller:normalRoute"

request.path = "/user/10"
request.method = "DELETE"
local route, parameters = r:route(request)
assertEquals(route, "Controller:regexRoute")
assertEquals(parameters._action, route)
assertEquals(parameters.uid, "10")

request.path = "/hello/world"
local route, parameters = r:route(request)

assertEquals(route, "Controller:normalRoute")
assertEquals(parameters._action, route)
assertEquals(parameters.a, "hello world")

request.path = "/nothing/to/see"

local route, parameters = r:route(request)
assertEquals(route, nil)
assertEquals(parameters, nil)

if process.argv[1] == "coverage" then
    dumpCoverage()
end
