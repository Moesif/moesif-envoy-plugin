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
 wget -O moesif-envoy-plugin.tar.gz https://github.com/Moesif/moesif-envoy-plugin/archive/0.1.3.tar.gz && \
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

If you're using Docker, Moesif has a working example usign Docker Compose in the [example dir](https://github.com/Moesif/moesif-envoy-plugin/tree/master/example)

### To run the example:

Modify the example files `Dockerfile-envoy` and `envoy.yml` for use with your live application. 

1. `cd` into the example dir
2. Add your Moesif Application Id to `envoy.yml`
3. Run the command `docker-compose up -d`

### To run the HTTPS example:

Envoy's Dynamic forward proxy will not normally terminate an SSL connection and will instead tunnel to proxied service. 
In order for API observability tools like Moesif to capture traffic, you need to configure Envoy to terminate the SSL connection.

In order to do so, do the following:

1. `cd` into the example dir
2. Add your Moesif Application Id to `envoy-https.yml`
3. Expose port `"8443:8443"` in `docker-compose.yaml`
4. Generate a self-signed certificate pair using: (Please change the common name as required)
    `$ openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes -subj '/CN=localhost'`
5. Please update the keys in the `transport_socket` section in `envoy-https.yml`. Incase, if you don't want to copy the keys in the file, you could provide the path where keys are located. Please update the section if passing the path - 

```yaml
transport_socket:
name: envoy.transport_sockets.tls
typed_config:
    "@type": type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.DownstreamTlsContext
    common_tls_context:
    tls_certificates:
        certificate_chain: { filename: "/etc/envoy/ssl/cert.pem" }
        private_key: { filename: "/etc/envoy/ssl/key.pem" }
        password: { inline_string: "XXXXX" }    
```

6. Update the Docker cmd to use `envoy-https.yaml` instead of `envoy.yml`. This can be done by updating last line in `Dockerfile-envoy` to `CMD ["/usr/local/bin/envoy", "-c", "/etc/envoy-https.yaml", "-l", "debug", "--service-cluster", "proxy"]`
7. Run the command `docker-compose up -d`

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

## How to enable Envoy plugin inside Istio's sidecars

1. If you've `istio` already installed, and `istio-system` namespace available, skip this step. If not you could download and install `istio`. 

- Download (Linux or macOS):

    ```bash
    curl -L https://istio.io/downloadIstio | sh -
    ```

- Move to the Istio package directory. For example, if the package is istio-1.9.2:

    ```bash
    cd istio-1.9.2
    ```

- Add the istioctl client to your path (Linux or macOS):

    ```bash
    export PATH=$PWD/bin:$PATH
    ```

- For this example, we use the demo configuration profile. It’s selected to have a good set of defaults for testing, but there are other profiles for production or performance testing.

    ```bash
    istioctl install --set profile=demo
    ```

2. Clone this repo and edit the `istio-example/envoy-filter.yaml` file to set your actual Moesif Application Id.

    Your Moesif Application Id can be found in the [_Moesif Portal_](https://www.moesif.com/).
    After signing up for a Moesif account, your Moesif Application Id will be displayed during the onboarding steps. 

    You can always find your Moesif Application Id at any time by logging 
    into the [_Moesif Portal_](https://www.moesif.com/), click on the top right menu,
    and then clicking _API Keys_.

3. At this point, make sure `istio-system` namespace is available since we're going to deploy app and enable envoy-filter in `istio-system` for this particular example. It could be verified by running this command

    ```bash
    kubectl get namespace
    ```

4. Navigate to `istio-example` directory.

5. Create a configMap which will be consumed by Pods as configuration file in a volume.

    ```bash
    kubectl create -f configMap.yaml -n istio-system
    ```

6. Create a Pod and manually inject the sidecar before deploying the nginx application with the following command:

    ```bash
    kubectl apply -n istio-system -f <(istioctl kube-inject -f nginx.yaml)
    ```
7. Verify the `nginx` pod is running
    ```bash
    kubectl get pods -n istio-system
    ```

8. Verify the deployment is ready and available
    ```bash
    kubectl get deployment -o wide -n istio-system
    ```

9. Create Envoy filter

    ```bash
    kubectl apply -f envoy-filter.yaml -n istio-system
    ```

10. Set the SOURCE_POD environment variable to the name of your source pod:

    ```bash
    export SOURCE_POD=$(kubectl get pod -n istio-system -l app=nginx -o jsonpath={.items..metadata.name})
    echo $SOURCE_POD
    ```
11. Now you could send request to an external service, and data should be captured in the corresponding Moesif account.

    ```bash
    kubectl -n istio-system exec "$SOURCE_POD" -c nginx -- curl -XGET -sSL  -H "Content-Type:application/json" -o /dev/null -D - http://httpbin.org/uuid -d "{\"test\": \"sf\"}"
    ```

12. You could tail Logs
    ```bash
    kubectl logs --follow -l app=nginx -c istio-proxy -n istio-system
    ```
Congratulations! If everything was done correctly, Moesif should now be tracking all network requests. If you have any issues with set up, please reach out to support@moesif.com.

## Other integrations

To view more documentation on integration options, please visit __[the Integration Options Documentation](https://www.moesif.com/docs/getting-started/integration-options/).__
