local core = require("moesif.core")

local _M = {}

-- Moesif Context
local ctx = {
    application_id = nil,
    batch_size = 5,
    user_id_header = nil,
    company_id_header = nil,
    metadata = {},
    disable_capture_request_body = false,
    disable_capture_response_body = false,
    request_header_masks = {},
    response_header_masks = {},
    request_body_masks = {},
    response_body_masks = {},
    debug = false,

}

-- Set application Id
function _M.set_application_id(application_id)
    if type(application_id) == "string" then 
        ctx["application_id"] = application_id
    end
end

-- Set Batch Size
function _M.set_batch_size(batch_size)
    if type(batch_size) == "number" then 
        ctx["batch_size"] = batch_size
    end
end

-- Set User Id Header Name
function _M.set_user_id_header(user_id_header)
    if type(user_id_header) == "string" then 
        ctx["user_id_header"] = user_id_header
    end
end

-- Set Company Id Header Name
function _M.set_company_id_header(company_id_header)
    if type(company_id_header) == "string" then 
        ctx["company_id_header"] = company_id_header
    end
end

-- Set Event Metadata
function _M.set_metadata(metadata)
    if type(metadata) == "table" then 
        ctx["metadata"] = metadata
    end
end

-- Set flag to true to disable capturing request body
function _M.set_disable_capture_request_body(disable_capture_request_body)
    if type(disable_capture_request_body) == "boolean" then 
        ctx["disable_capture_request_body"] = disable_capture_request_body
    end
end

-- Set flag to true to disable capturing response body
function _M.set_disable_capture_response_body(disable_capture_response_body)
    if type(disable_capture_response_body) == "boolean" then 
        ctx["disable_capture_response_body"] = disable_capture_response_body
    end
end

-- Set request header fields to be masked
function _M.set_request_header_masks(request_header_masks)
    if type(request_header_masks) == "table" then 
        ctx["request_header_masks"] = request_header_masks
    end
end

-- Set response header fields to be masked
function _M.set_response_header_masks(response_header_masks)
    if type(response_header_masks) == "table" then 
        ctx["response_header_masks"] = response_header_masks
    end
end

-- Set request body fields to be masked
function _M.set_request_body_masks(request_body_masks)
    if type(request_body_masks) == "table" then 
        ctx["request_body_masks"] = request_body_masks
    end
end

-- Set response body fields to be masked
function _M.set_response_body_masks(response_body_masks)
    if type(response_body_masks) == "table" then 
        ctx["response_body_masks"] = response_body_masks
    end
end

-- Set flag to true to enable debug logs
function _M.set_debug(debug)
    if type(debug) == "boolean" then 
        ctx["debug"] = debug
    end
end

-- Init Global variables
batch_events = {}
last_updated_time = nil
app_confg = {}

function build_url(handler)
    local uri = nil
    local x_forwarded_proto = handler:headers():get("x-forwarded-proto")
    if x_forwarded_proto ~= nil then 
        uri = x_forwarded_proto .. "://"
    else
        uri = "http" .. "://"
    end

    local authority = handler:headers():get(":authority")
    if authority ~= nil then 
        uri = uri .. authority
    else
        uri = uri .. "localhost"
    end

    local path = handler:headers():get(":path")
    if path ~= nil then 
        uri = uri .. path
    else
        uri = uri .. "/"
    end

    return uri
end

function getLocalAddress(handler)
    return handler:streamInfo():downstreamLocalAddress()
end

function getRemoteAddress(handler)
    return handler:streamInfo():downstreamDirectRemoteAddress()
end

-- Function to log event request
function _M.log_request(handler)

    -- Check if application Id is set
    if ctx["application_id"] ~= nil and string.lower(handler:headers():get(":method")) ~= "connect" then 
        -- Create object to store moesif event and moesif event request
        local moesif_event = {}
        local moesif_request = {}

        -- Request Time
        moesif_request["time"] = core.helpers.get_current_time_in_ms()

        -- Request URI
        moesif_request["uri"] = build_url(handler)

        -- Request Verb
        moesif_request["verb"] = handler:headers():get(":method")

        -- Request Headers
        moesif_request["headers"] = core.helpers.fetch_headers(handler:headers())

        -- Mask Headers 
        if next(ctx["request_header_masks"]) ~= nil then
            moesif_request["headers"] = core.helpers.mask_headers(moesif_request["headers"], ctx["request_header_masks"])
        end
        
        -- Request body
        if ctx["disable_capture_request_body"] then 
            moesif_request["body"], moesif_request["transfer_encoding"] = nil, nil
        else
            local raw_request_body = core.helpers.fetch_raw_body(handler)
            if raw_request_body ~= nil and raw_request_body ~= '' then 
                moesif_request["body"], moesif_request["transfer_encoding"] = core.helpers.parse_body(moesif_request["headers"], raw_request_body, ctx["request_body_masks"])
            end
        end

        -- User Agent String
        moesif_request["user_agent_string"] = handler:headers():get("user-agent")

        -- Ip Address
        local found_remote_address, direct_remote_address = pcall(getRemoteAddress, handler)
        if found_remote_address then 
            moesif_request["ip_address"] = direct_remote_address
        else
            local found_local_address, local_address = pcall(getLocalAddress, handler)
            if found_local_address then
                moesif_request["ip_address"] = local_address
            end
        end

        -- User Id
        if ctx["user_id_header"] ~= nil then 
            moesif_event["user_id"] = handler:headers():get(ctx["user_id_header"])
        end

        -- Company Id
        if ctx["company_id_header"] ~= nil then 
            moesif_event["company_id"] = handler:headers():get(ctx["company_id_header"])
        end

        -- Add request object to moesif_event
        moesif_event["request"] = moesif_request

        -- Add Moesif Event object to the current context
        handler:streamInfo():dynamicMetadata():set("context", "moesif_event", moesif_event)
        
    else
        if ctx["debug"] then 
            handler:logDebug("[moesif] !!!!! Please provide Moesif application Id. Please note, Moesif will skip logging the event incase the request method is CONNECT even if application Id is already provided. !!!!!")
        end
    end
end

-- Function to log event response and send event to Moesif
function _M.log_response(handler)

    -- Debug flag
    local debug = ctx["debug"]

    -- Check if application Id is set
    if ctx["application_id"] ~= nil then 

        -- Fetch current context
        local current_context = handler:streamInfo():dynamicMetadata():get("context")
        -- Check if request is captured and current context is not nil
        if current_context ~= nil then 

            -- Fetch moesif_event from the context
            local moesif_event = current_context["moesif_event"]

            -- If the app config body is of type string, decode it to convert it to table. 
            -- This will only execute first time when the response is of type string.
            if app_config ~= nil and type(app_config) == "string" then 
                app_config = core.json:decode(app_config)
            end

            -- Generate random percentage to sample event
            local random_percentage = math.random() * 100

            -- Fetch sample rate based on user or company id
            local sampling_rate = 100
            if type(app_config) == "table" and next(app_config) ~= nil then 
                if app_config["user_sample_rate"] ~=nil and type(app_config["user_sample_rate"]) == "table" and next(app_config["user_sample_rate"]) ~= nil and moesif_event["user_id"] ~=nil and app_config["user_sample_rate"][moesif_event["user_id"]] then 
                    sampling_rate = app_config["user_sample_rate"][moesif_event["user_id"]]
                elseif app_config["company_sample_rate"] ~=nil and type(app_config["company_sample_rate"]) == "table" and next(app_config["company_sample_rate"]) ~= nil and moesif_event["company_id"] ~=nil and app_config["company_sample_rate"][moesif_event["company_id"]] then
                    sampling_rate = app_config["company_sample_rate"][moesif_event["company_id"]]
                end
            end

            -- Check if event need to be sampled
            if sampling_rate > random_percentage then

                -- Create object to store moesif response 
                local moesif_response = {}

                -- Response Time
                moesif_response["time"] = core.helpers.get_current_time_in_ms()

                -- Response status
                moesif_response["status"] = tonumber(handler:headers():get(":status"))

                -- Response headers
                moesif_response["headers"] = core.helpers.fetch_headers(handler:headers())

                -- Mask Headers
                if next(ctx["response_header_masks"]) ~= nil then
                    moesif_response["headers"] = core.helpers.mask_headers(moesif_response["headers"], ctx["response_header_masks"])
                end

                -- Response body
                if ctx["disable_capture_response_body"] then 
                    moesif_response["body"], moesif_response["transfer_encoding"] = nil, nil
                else
                    local raw_response_body = core.helpers.fetch_raw_body(handler)
                    if raw_response_body ~= nil and raw_response_body ~= ''  then 
                        moesif_response["body"], moesif_response["transfer_encoding"] = core.helpers.parse_body(moesif_response["headers"], raw_response_body, ctx["response_body_masks"])
                    end
                end

                -- Add request object to moesif_event
                moesif_event["response"] = moesif_response

                -- Add Direction to moesif_event
                moesif_event["direction"] = "Incoming"

                -- Add Metadata to moesif_event
                if next(ctx["metadata"]) ~= nil then
                    moesif_event["metadata"] = ctx["metadata"]
                end

                -- Add Event to the queue and encode array before sending to moesif
                table.insert(batch_events, moesif_event)

                -- Check if number of events in the batch matches batch size
                if #batch_events == ctx["batch_size"] then 
                    
                    -- Encode body before sending
                    local encode_value = core.json:encode(batch_events)

                    -- Compress payload when sending data to moesif
                    local payload
                    local send_events_headers = {
                        [":method"] = "POST",
                        [":path"] = "/_moesif/api/v1/events/batch",
                        [":authority"] = "moesifprod",
                        ["content-type"] = "application/json",
                        ["x-moesif-application-id"] = ctx["application_id"],
                        ["user-agent"] = "envoy-plugin-moesif/0.1.4"
                    }
                    local ok, compressed_body = pcall(core.lib_deflate["CompressDeflate"], core.lib_deflate, encode_value)
                    if not ok then 
                        payload = encode_value
                    else
                        send_events_headers["content-encoding"] = "deflate"
                        payload = compressed_body
                    end 

                    -- Send events to moesif
                    local _, _ = handler:httpCall("moesifprod", send_events_headers, payload, 5000, true)

                    if debug then 
                        handler:logDebug("[moesif] Events sent successfully")
                    end

                    -- Reset event queue
                    batch_events = {}

                    -- Check if need to fetch application configuration
                    if last_updated_time == nil or (os.time() > last_updated_time + 300) then
                        local app_config_headers, app_config_body = handler:httpCall(
                            "moesifprod",
                            {
                                [":method"] = "GET",
                                [":path"] = "/_moesif/api/v1/config",
                                [":authority"] = "moesifprod",
                                ["content-type"] = "application/json",
                                ["x-moesif-application-id"] = ctx["application_id"]
                            },
                            "",
                            5000
                        )

                        -- Save app config response
                        app_config = app_config_body

                        if debug then 
                            handler:logDebug("[moesif] successfully fetched the application configuration")
                        end

                        -- Update the last updated time since we fetch the app config
                        last_updated_time = os.time()
                    end
                end
            else
                if debug then 
                    handler:logDebug("[moesif] Skipped Event due to sampling percentage - " .. tostring(sampling_rate) .. " and random number - " .. tostring(random_percentage))
                end
            end
        else
            if debug then 
                handler:logDebug("[moesif] Request is not captured as current context is nil, skipped logging event to Moesif.")
            end
        end
    else
        if debug then 
            handler:logDebug("[moesif] !!!!! Please provide Moesif application Id !!!!!")
        end
    end
end

return _M
