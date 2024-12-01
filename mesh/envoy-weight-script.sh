#!/bin/bash

# Function to generate Envoy config file
generate_envoy_config() {
  local old_service=$1
  local new_service=$2
  local old_weight=$3
  local new_weight=$4

  # Create the Envoy configuration file
  cat <<EOF > envoy_hot_reload.yaml
static_resources:
  listeners:
    - name: listener_0
      address:
        socket_address:
          address: 0.0.0.0
          port_value: 8000
      filter_chains:
        - filters:
            - name: envoy.filters.network.http_connection_manager
              typed_config:
                "@type": "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager"
                stat_prefix: ingress_http
                route_config:
                  name: local_route
                  virtual_hosts:
                    - name: backend
                      domains: ["*"]
                      routes:
                        - match:
                            prefix: "/"
                          route:
                            weighted_clusters:
                              clusters:
                                - name: $old_service
                                  weight: $old_weight
                                - name: $new_service
                                  weight: $new_weight
                http_filters:
                  - name: envoy.filters.http.router
                    typed_config:
                      "@type": "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router"
  clusters:
    - name: $old_service
      connect_timeout: "1s"
      type: STRICT_DNS
      load_assignment:
        cluster_name: $old_service
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: "$old_service.envoy-demo.svc.cluster.local"
                      port_value: 3030
    - name: $new_service
      connect_timeout: "1s"
      type: STRICT_DNS
      load_assignment:
        cluster_name: $new_service
        endpoints:
          - lb_endpoints:
              - endpoint:
                  address:
                    socket_address:
                      address: "$new_service.envoy-demo.svc.cluster.local"
                      port_value: 3030

admin:
  access_log_path: "/tmp/admin_access.log"
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8081  # Corrected port value for the admin interface
EOF

  echo "Envoy configuration file generated successfully!"
}

# Function to perform a hot restart
reload_envoy() {
  local envoy_admin_url=$1
  echo "Triggering hot restart on Envoy at $envoy_admin_url"
  
  curl -X POST "$envoy_admin_url/hot_restart_version"
  if [ $? -eq 0 ]; then
    echo "Envoy successfully reloaded!"
  else
    echo "Failed to reload Envoy. Check Envoy admin URL or logs."
  fi
}

# Prompt for user input
echo "Enter the old service name:"
read old_service

echo "Enter the new service name:"
read new_service

echo "Enter the traffic weight for the old service (0-100):"
read old_weight

echo "Enter the traffic weight for the new service (0-100):"
read new_weight

echo "Enter the Envoy admin URL (e.g., http://localhost:8081):"
read envoy_admin_url

# Validate weights sum to 100%
if [ $((old_weight + new_weight)) -ne 100 ]; then
  echo "Error: The sum of old_weight and new_weight must be 100."
  exit 1
fi

# Generate the Envoy config and reload Envoy
generate_envoy_config $old_service $new_service $old_weight $new_weight
reload_envoy $envoy_admin_url
