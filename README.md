# Moesif Envoy Plugin

The Moesif Envoy plugin captures API traffic from [Envoy Service Proxy](https://www.envoyproxy.io/)
and logs it to [Moesif API Analytics](https://www.moesif.com). This plugin leverages an asynchronous design and doesn’t add any latency to your API calls.

- Envoy is an open-source Service Proxy.
- Moesif is an API analytics and monitoring service.

[Source Code on GitHub](https://github.com/Moesif/moesif-envoy-plugin)

## How to install

### 1. Download plugin files

Download the latest release into your current working directory for Envoy.

```bash
 wget -O moesif-envoy-plugin.tar.gz https://github.com/Moesif/moesif-envoy-plugin/archive/0.1.1.tar.gz && \
    tar -xf moesif-envoy-plugin.tar.gz -C ./ --strip-components 1
```
### 2. Update Envoy config

In your `envoy.yaml`, add a `http_filters` section along with the below code snippet. 

Your Moesif Application Id can be found in the [_Moesif Portal_](https://www.moesif.com/).
After signing up for a Moesif account, your Moesif Application Id will be displayed during the onboarding steps. 

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

Add a `clusters` config with the below code snippet.

```yaml
 clusters:
  - name: moesifprod
    connect_timeout: 0.25s
    type: logical_dns
    http2_protocol_options: {}
    lb_policy: round_robin
    load_assignment:
      cluster_name: moesifprod
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: api.moesif.net
                port_value: 443
    transport_socket:
      name: envoy.transport_sockets.tls
      typed_config:
        "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.UpstreamTlsContext
        sni: api.moesif.net
        common_tls_context: 
          validation_context:
            match_subject_alt_names:
            - exact: "*.moesif.net"
            trusted_ca:
              filename: /etc/ssl/certs/ca-certificates.crt
```

_If you downloaded the files to a different location, replace `moesif.plugins.log` with the correct path_

### 3. Restart Envoy
Make a few API calls to test that they are logged to Moesif.

## Docker Compose

If you're using Docker, Moesif has a sample app available in the [example](https://github.com/Moesif/moesif-envoy-plugin/tree/master/example)
To run the sample:

1. `cd` into the example dir
2. Add your Moesif Application Id to `envoy.yml`
3. Run the command `docker-compose up -d`

You can modify the `Dockerfile-envoy` and `envoy.yml` for use with your live application. 

## Configuration options

#### __`set_application_id()`__
(__required__), _string_, is obtained via your Moesif Account, this is required.

#### __`set_batch_size()`__
(optional) _number_, default `5`. Maximum batch size when sending to Moesif.

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

1. Clone this repo and edit the `example/envoy.yaml` file to set your actual Moesif Application Id.

    Your Moesif Application Id can be found in the [_Moesif Portal_](https://www.moesif.com/).
    After signing up for a Moesif account, your Moesif Application Id will be displayed during the onboarding steps. 

    You can always find your Moesif Application Id at any time by logging 
    into the [_Moesif Portal_](https://www.moesif.com/), click on the top right menu,
    and then clicking _API Keys_.

2. Build docker image and start container

    ```
    cd example && docker-compose up -d
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