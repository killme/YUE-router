--[[
    Module for easy routing.
]]

local Object = require "luvit.core".Object
local escapeNeedle = require "luautil.regex".escape

--[[
    Copies a table.
    This will also set metatables and will recursively copy if <code>deep</code> is specified.

    @todo Move to better place.

    @param tin  The table to copy.
    @param deep Whether or not to recursively copy the table.

    @returns The copied table.
]]
local function copyTable(tin, deep)
    local t = {}

    for k, v in pairs(tin) do
        if deep and type(v) == "table" then
            t[k] = copyTable(v, deep)
        else
            t[k] = v
        end
    end

    return setmetatable(t, getmetatable(tin))
end

--[[
    Builds a hashmap backed matcher. Used to verify method parameters.

    @param options      The options as passed to the route constructor.
    @param parameter    The parameter to mach on, should be the same as passed to request and options.
    @param defaults     The default value to match on, may me <code>"*"</code> or a table.

    @returns    A table containing the values to match on.
                When anything is matched the first value of the table is <code>"*"</code>.
    @returns    A function that returns true when the request passed to the function is matched and false when not.
]]
local function buildHashMapMatcher(options, parameter, defaults)
    local matchValues = {}
    options[parameter] = options[parameter] == nil and defaults or options[parameter]

    if options[parameter] == "*" then
        matchValues[1] = "*"
    else
        assert(type(options[parameter]) == "table", "The " .. parameter .. " option must be a table or \"*\"")

        for k, value in pairs(options[parameter]) do
            matchValues[value] = true
        end
    end

    return matchValues, function(request, params)
        return matchValues[1] == "*" or matchValues[request[parameter]] or false
    end
end

local Route = Object:extend()

--[[
    Initialises a new route.

    @param options  The options to pass to the route.
                    Valid options are: method, host, path.
]]
function Route:initialize(options)
    options = options or {}
    self.matchMethods, self._matchMethod    = buildHashMapMatcher(options, "method", { "GET", "HEAD" })
    self.matchHosts, self._matchHost        = buildHashMapMatcher(options, "host", "*")
    self.matchPaths, self._matchPath        = buildHashMapMatcher(options, "path", {})

    self.parameters = options.parameters or {}
end

--[[
    Checks if a request matches this route.

    @returns Whether or not this route matches.
    @returns The parameters that were set for this route and during the matching process.
]]
function Route:match(request)
    local parameters = copyTable(self.parameters, true)

    return self._matchMethod(request, parameters)
            and self._matchHost(request, parameters)
            and self._matchPath(request, parameters),
            parameters
end

local RegexRoute = Route:extend()

--[[
    Initialises a new pattern backed route.

    @param options  The options to pass to the route.
                    Valid options are: method, host, path, pathPatterns.
]]
function RegexRoute:initialize(options)
    options.path = options.path or "*"
    Route.initialize(self, options)

    self.matchPathPatterns = options.pathPatterns or {}
    assert(type(self.matchPathPatterns) == "table", "pathPatterns was not a table.")

    self:rebuildPatterns()
end

--[[
    Parses the paths and turns them into regexes that can be matched to paths.
]]
function RegexRoute:rebuildPatterns()
    self.matchPatterns = {}

    for i, path in pairs(self.matchPathPatterns) do
        local paramNames = {}
        local pattern
        if path:find("{(.-)}") then
            pattern =
                path:gsub("^([^}]-){", function(...)
                    return escapeNeedle(...) .. "{"
                end)
                :gsub("}(.-){", function(...)
                    return "}"..escapeNeedle(...).."{"
                end)
                :gsub("}([^{]-)$", function(...)
                    return "}"..escapeNeedle(...)
                end)
                :gsub("{(.-)}", function(match, ...)
                    if match:sub(1, 1) ~= "{" then
                        local d, e, f = match:find("^(.-):")
                        local name = f or match

                        if name:sub(1, 1) == "_" then
                            error("Parameter names may not start with _.")
                        end

                        paramNames[#paramNames+1] = name
                        local a, b, c = match:find(":(.*)$")
                        return c and "("..c..")" or "([^/]-)"
                    end
                    return escapeNeedle(match)
                end)
        else
            pattern = escapeNeedle(path)
        end

        self.matchPatterns[#self.matchPatterns+1] = {
            pattern,
            paramNames
        }
    end
end

function RegexRoute:match(request)
    local matched, parameters = Route.match(self, request)

    if not matched then
        return matched, parameters
    end

    for i, matchPattern in pairs(self.matchPatterns) do
        local res = {
            request.path:match(matchPattern[1])
        }

        if res[1] then
            for i, name in pairs(matchPattern[2]) do
                parameters[name] = res[i]
            end

            parameters._matchPattern = matchPattern

            return matched, parameters
        end
    end

    return false, parameters
end

local Router = Object:extend()

--[[
    Initialises the router.
]]

function Router:initialize()
    self.routes = {}
end

--[[
    Finds an action name and parameters from a request.

    @param request The Request to find the routes for.

    @returns The name of the action or nil when none could be found
    @returns The parameters additional to the action.
]]
function Router:route(request)
    for k, route in pairs(self.routes) do
        local match, parameters = route:match(request)

        if match then
            return parameters._action, parameters
        end
    end

    return nil, nil
end

--[[
    Registers a route.

    @param route The route to register.
]]
function Router:addRoute(route)
    self.routes[#self.routes+1] = route
end

--[[
    Removes the specified route.

    @param route The route to remove.
]]
function Router:removeRoute(route)
    local passed = 0

    for i, r in pairs(self.routes) do
        if route == r then
            passed = passed + 1
        end

        local v = self.routes[i+passed]
        self.routes[i+passed] = nil
        self.routes[i] = v
    end
end

return {
    Route = Route,
    RegexRoute = RegexRoute,
    Router = Router
}
