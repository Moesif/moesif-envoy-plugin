
local _M = {}
local base64 = require("moesif.core.base64")
local json = require("moesif.core.json")
local zzlib = require("moesif.core.zzlib")

-- Function to fetch headers
function _M.fetch_headers(header_object)
    local headers = {}
    for key, value in pairs(header_object) do
        headers[key] = value
    end
    return headers
end

-- Return nil when body is of type xml/html instead of erroring out
function json:onDecodeOfHTMLError(message, text, location, etc)
    return nil
end

-- Return nil when json decoding fails instead of erroring out
function json:onDecodeError(message, text, location, etc)
    return nil
end

-- Function to check if the body is of type json
local function is_valid_json(body)
    return type(body) == "string" and string.sub(body, 1, 1) == "{" or string.sub(body, 1, 1) == "["
end

-- Function to base64 enocde body
local function base64_encode_body(body)
    return base64.encode(body), 'base64'
end

local function safe_clock ()
    if os.clock == nil then
        return string.format('%.2f', 0.0 * 1000)
    else
        return tostring(os.clock() * 1000)
    end
end

-- Function to get current time in milliseconds
function _M.get_current_time_in_ms()
    local current_time_since_epoch = os.time(os.date("!*t"))
    return os.date("!%Y-%m-%dT%H:%M:%S.", current_time_since_epoch) .. string.match(safe_clock(), "%d%.(%d+)")
end

-- Function fetch raw body
function _M.fetch_raw_body(handle, debug)
    local body = handle:body()
    if body ~= nil and body ~= '' then
        local body_size = body:length()
        local body_bytes = body:getBytes(0, body_size)
        if debug then
            handle:logDebug("[moesif] Fetched Raw Body - " .. tostring(body_bytes)) 
        end
        return tostring(body_bytes)
    else
        if debug then
            handle:logDebug("[moesif] Fetched Raw Body is nil") 
        end
        return nil
    end
end

-- Function to process request/response body
function process_data(raw_body, mask_fields)
    local body_entity = nil
    local body_transfer_encoding = nil

    -- Process data
    if is_valid_json(raw_body) then
        local json_decoded_body = json:decode(raw_body)
        if json_decoded_body == nil then
            body_entity, body_transfer_encoding = base64_encode_body(raw_body)
        else
            if next(mask_fields) == nil then
                body_entity, body_transfer_encoding = json_decoded_body, 'json' 
            else
                local ok, mask_result = pcall(mask_body, json_decoded_body, mask_fields)
                if not ok then
                  body_entity, body_transfer_encoding = json_decoded_body, 'json' 
                else
                  body_entity, body_transfer_encoding = mask_result, 'json' 
                end
            end
        end
    else
        body_entity, body_transfer_encoding = base64_encode_body(raw_body)
    end
    return body_entity, body_transfer_encoding
end

-- Function to decompress gzip body
function decompress_body(raw_body, mask_fields)
    local body_entity = nil
    local body_transfer_encoding = nil

    local ok, decompressed_body = pcall(zzlib.gunzip, raw_body)
    if not ok then
        body_entity, body_transfer_encoding = base64_encode_body(raw_body)
    else
        if is_valid_json(decompressed_body) then 
            body_entity, body_transfer_encoding = process_data(decompressed_body, mask_fields)
        else 
            body_entity, body_transfer_encoding = base64_encode_body(decompressed_body)
        end
    end
    return body_entity, body_transfer_encoding
end

-- Function to parse request/response body
function _M.parse_body(headers, raw_body, mask_fields)
    local body_entity = nil
    local body_transfer_encoding = nil

    if headers["content-type"] ~= nil and string.find(headers["content-type"], "json") then
        body_entity, body_transfer_encoding = process_data(raw_body, mask_fields)
    elseif headers["content-encoding"] ~= nil and type(raw_body) == "string" and string.find(headers["content-encoding"], "gzip") then
        body_entity, body_transfer_encoding = decompress_body(raw_body, mask_fields)
    else
        body_entity, body_transfer_encoding = base64_encode_body(raw_body)
    end
    return body_entity, body_transfer_encoding
end

-- Function to mask fields
function mask_body(body, masks)
    if masks == nil then return body end
    if body == nil then return body end
    for mask_key, mask_value in pairs(masks) do
        if body[mask_value] ~= nil then body[mask_value] = nil end
        for body_key, body_value in next, body do
            if type(body_value)=="table" then mask_body(body_value, masks) end
        end
    end
    return body
end

-- Function to mask headers
function _M.mask_headers(headers, mask_fields)
    local mask_headers = nil
      
    for k,v in pairs(mask_fields) do
      mask_fields[k] = v:lower()
    end
  
    local ok, mask_result = pcall(mask_body, headers, mask_fields)
    if not ok then
      mask_headers = headers
    else
      mask_headers = mask_result
    end
    return mask_headers
  end

return _M
