# Moesif Envoy Plugin

The Moesif Envoy plugin captures API traffic from [Envoy Service Proxy](https://www.envoyproxy.io/)
and logs it to [Moesif API Analytics](https://www.moesif.com). This plugin leverages an asynchronous design and doesn’t add any latency to your API calls.

- Envoy is an open-source Service Proxy.
- Moesif is an API analytics and monitoring service.

[Source Code on GitHub](https://github.com/Moesif/moesif-envoy-plugin)

## How to use

In the `envoy.yaml`, enable lua http_filters and import moesif plugin in inline_code as shown below. Ensure that the `log.log_request` and `log.log_response` functions are being called respectively from `envoy_on_request` and `envoy_on_response` to capture events in Moesif.

`Please note`: If you've not setuped envoy using docker, you could place all the plugin files under `moesif/` in any location, and you've to import the log file from that location, for example `local log = require("Path where moesif/plugins/log file is placed")`. 

```yaml
 http_filters: 
    - name: envoy.filters.http.lua
    typed_config:
        "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
        inline_code: |
        local log = require("moesif.plugins.log")

        -- Moesif configs
        log.set_application_id("Your Moesif Application Id")
        -- ... For other options see below.

        function envoy_on_request(request_handle)
            -- Log Event Request to Moesif
            log.log_request(request_handle)
        end

        function envoy_on_response(response_handle)
            -- Log Event Response to Moesif
            log.log_response(response_handle)
        end                
```

## Configuration options

#### __`set_application_id()`__
(__required__), _string_, is obtained via your Moesif Account, this is required.

#### __`set_batch_size()`__
(optional) _number_, default `25`. Maximum batch size when sending to Moesif.

#### __`set_user_id_header()`__
(optional) _string_, Request header to use to identify the User in Moesif.

#### __`set_company_id_header()`__
(optional) _string_, Request header to use to identify the Company (Account) in Moesif.

#### __`set_metadata()`__
(optional) _table_, default `{}`. This allows you to associate the event with custom metadata. For example, you may want to save a VM instance_id, a trace_id, or a tenant_id with the request.

#### __`set_disable_capture_request_body()`__
(optional) _boolean_, default `false`. Set this flag to `true`, to disable logging of request body.

#### __`set_disable_capture_response_body()`__
(optional) _boolean_, default `false`. Set this flag to `true`, to disable logging of response body.

#### __`set_request_header_masks()`__
(optional) _table_, default `{}`. An array of request header fields to mask.

#### __`set_request_body_masks()`__
(optional) _table_, default `{}`. An array of request body fields to mask.

#### __`set_response_header_masks()`__
(optional) _table_, default `{}`. An array of response header fields to mask.

#### __`set_response_body_masks()`__
(optional) _table_, default `{}`. An array of response body fields to mask.

#### __`set_debug()`__
(optional) _boolean_, default `false`. Set this flag to `true`, to see debugging messages.

## How to test

1. Clone this repo and edit the `compose/envoy.yaml` file to set your actual Moesif Application Id.

    Your Moesif Application Id can be found in the [_Moesif Portal_](https://www.moesif.com/).
    After signing up for a Moesif account, your Moesif Application Id will be displayed during the onboarding steps. 

    You can always find your Moesif Application Id at any time by logging 
    into the [_Moesif Portal_](https://www.moesif.com/), click on the top right menu,
    and then clicking _API Keys_.

2. Build docker image and start container

    ```
    cd compose && docker-compose up -d
    ```

3. By default, The container is listening on port 8000. You should now be able to make a request: 

    ```bash
    curl --request GET \
        --url 'http://localhost:8000/?x=2&y=4' \
        --header 'Content-Type: application/json' \
        --header 'company_id_header: envoy_company_id' \
        --header 'user_id_header: envoy_user_id' \
        --data '{
            "envoy_event": true
        }'
    ```

4. The data should be captured in the corresponding Moesif account.

Congratulations! If everything was done correctly, Moesif should now be tracking all network requests. If you have any issues with set up, please reach out to support@moesif.com.

## Other integrations

To view more documentation on integration options, please visit __[the Integration Options Documentation](https://www.moesif.com/docs/getting-started/integration-options/).__