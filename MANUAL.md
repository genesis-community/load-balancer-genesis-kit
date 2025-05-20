# Load Balancer Genesis Kit Manual

The **Load Balancer Genesis Kit** deploys a HAProxy-backed load balancer for your applications. HAProxy is a reliable, high-performance TCP/HTTP load balancer with powerful traffic management capabilities.

## Features

The kit supports the following features:

### `vip`

When enabled, this feature deploys keepalived alongside HAProxy to provide a Virtual IP (VIP) address for high availability. If one HAProxy instance fails, the VIP will automatically fail over to another instance.

Example:
```yaml
features:
  - vip

params:
  virtual-router-id: 42  # Unique ID on your network (0-255)
  virtual-ip: 10.0.10.10 # The VIP address
```

### `static-ips`

When enabled, this feature allows you to specify static IP addresses for your load balancer VMs.

Example:
```yaml
features:
  - static-ips

params:
  ips: 
    - 10.0.0.10
    - 10.0.0.11
```

### `cf`

When enabled, this feature configures the load balancer specifically for Cloud Foundry, automatically setting up appropriate frontends and backends for the Gorouter and SSH proxy.

Example:
```yaml
features:
  - cf

params:
  cf-deployment: my-cf # Name of your CF deployment
  certificates:
    - ((vault my-cf.ssl-cert))
```

## Parameters

### Core Parameters

- `vm_type` - What type of VM to deploy. This type must exist in your cloud config. Defaults to `default`.

- `lb_network` - What network to deploy HAProxy into. This network must be defined in your cloud config. Defaults to `default`.

- `advanced_haproxy_config` - Any configuration values you want to deploy verbatim into HAProxy. If none, set to null string.

- `load_balancers` - Array of load balancer configurations you want to deploy with HAProxy.

- `instances` - Number of HAProxy instances to deploy. Defaults to 2.

- `availability_zones` - Which AZs to deploy to. Defaults to `z1`.

- `cpu` - CPU allocation for each VM. Defaults to 2.

- `ram` - RAM allocation in MB for each VM. Defaults to 2048.

- `disk` - Disk allocation in MB for each VM. Defaults to 16384.

- `stemcell_os` - The stemcell OS to use. Defaults to `ubuntu-xenial`.

- `stemcell_version` - The stemcell version to use. Defaults to `latest`.

### Load Balancer Configuration

Each entry in the `load_balancers` array can have the following properties:

- `name` - Name for this load balancer (required)
- `mode` - Either `http` or `tcp` (required)
- `port` - Port to listen on (required)
- `redirect_to_https` - If set to "all", redirects all HTTP traffic to HTTPS (optional, HTTP mode only)
- `tls` - TLS configuration (optional)
  - `certificates` - Array of certificate references
  - `protocols` - Array of TLS protocols to enable
  - `ciphers` - Array of ciphers to enable
- `acls` - Access control lists (optional)
  - `name` - Name for the ACL
  - `allow` - Array of IPs/CIDRs to allow
  - `deny` - Array of IPs/CIDRs to deny
- `backend` - Backend configuration (required)
  - `addresses` - Array of backend addresses (format: IP:PORT)
  - `link` - BOSH link to consume (alternative to addresses)
  - `port` - Port for the backend if using a link

### VIP Parameters (with `vip` feature)

- `virtual-router-id` - VRRP Virtual Router ID (a network-unique integer between 0 and 255)
- `virtual-ip` - VRRP Virtual IPv4 Address

### Static IPs Parameters (with `static-ips` feature)

- `ips` - Array of static IP addresses to assign to the load balancer instances

### Cloud Foundry Parameters (with `cf` feature)

- `cf-deployment` - Name of the CF deployment to integrate with (defaults to `<env>-cf`)
- `allow-to-internal` - CIDR range to allow to internal CF components (defaults to `0.0.0.0/0`)
- `gorouter-http-port` - HTTP port for the gorouter (defaults to `80`)
- `gorouter-ssh-port` - SSH port for the gorouter (defaults to `2222`)
- `certificates` - Array of certificates for HTTPS
- `protocols` - TLS protocols to enable (optional, defaults to TLS 1.0, 1.1, and 1.2)
- `ciphers` - TLS ciphers to enable (optional, defaults to a secure set of ciphers)

## Examples

### Basic HTTP Load Balancer

```yaml
kit:
  name: load-balancer
  version: 0.0.1

params:
  load_balancers:
  - name: front-door
    mode: http
    port: 80
    backend:
      addresses:
        - 10.0.0.10:8080
        - 10.0.0.11:8080
  advanced_haproxy_config: null
  haproxy_network: default
  vm_type: default
```

### HTTPS Load Balancer with TLS Termination

```yaml
kit:
  name: load-balancer
  version: 0.0.1

params:
  load_balancers:
  - name: secure-frontend
    mode: http
    port: 443
    acls:
    - name: internal-only
      allow:
        - 10.0.0.0/8
    backend:
      addresses:
        - 10.0.0.10:8443
    tls:
      certificates:
      - ((vault "path/to/cert:combined"))
  advanced_haproxy_config: null
  haproxy_network: default
  vm_type: default
```

### High Availability Load Balancer with VIP

```yaml
kit:
  name: load-balancer
  version: 0.0.1

features:
  - vip

params:
  virtual-router-id: 42
  virtual-ip: 10.0.0.200
  load_balancers:
  - name: ha-frontend
    mode: http
    port: 80
    backend:
      addresses:
        - 10.0.0.10:8080
        - 10.0.0.11:8080
  advanced_haproxy_config: null
  haproxy_network: default
  vm_type: default
```

### Cloud Foundry Integration

```yaml
kit:
  name: load-balancer
  version: 0.0.1

features:
  - cf

params:
  cf-deployment: my-cf
  certificates:
    - ((vault "path/to/cert:combined"))
  advanced_haproxy_config: null
  haproxy_network: default
  vm_type: default
```

## Addons

The Load Balancer Genesis Kit provides several addon commands to help manage your deployment:

### `cf` - Configure Load Balancers

Interactive addon for configuring load balancers in your environment.

```bash
genesis do my-env -- cf
```

Options:
- `--reset` - Reset the load balancer configuration to defaults

### `rc` - Generate Runtime Config

Generates a BOSH runtime config for HAProxy metrics agent.

```bash
genesis do my-env -- rc
```

Options:
- `--upload` - Upload the generated runtime config to the BOSH director

### `st` - Display Status

Show the current status of your load balancer deployment.

```bash
genesis do my-env -- st
```

Options:
- `--detailed` - Show detailed statistics and metrics

## Advanced HAProxy Configuration

For advanced HAProxy configurations that aren't covered by the Genesis Kit parameters, you can use the `advanced_haproxy_config` parameter to specify raw HAProxy configuration that will be included in the generated HAProxy config:

```yaml
params:
  advanced_haproxy_config: |
    maxconn 10000
    timeout connect 10s
    timeout client 30s
    timeout server 30s
    stats socket /var/vcap/sys/run/haproxy/haproxy.sock mode 600 level admin
```

## Troubleshooting

### Common Issues

#### Load Balancer Not Forwarding Traffic

1. Check if HAProxy is running:
   ```bash
   genesis do my-env -- st --detailed
   ```

2. Verify backend servers are responding:
   ```bash
   bosh -d my-env ssh haproxy/0 "curl -I http://BACKEND_IP:BACKEND_PORT"
   ```

3. Check HAProxy logs:
   ```bash
   bosh -d my-env ssh haproxy/0 "sudo cat /var/vcap/sys/log/haproxy/haproxy.log"
   ```

#### VIP Not Working

1. Verify keepalived is running:
   ```bash
   bosh -d my-env ssh haproxy/0 "sudo systemctl status keepalived"
   ```

2. Check keepalived logs:
   ```bash
   bosh -d my-env ssh haproxy/0 "sudo cat /var/vcap/sys/log/keepalived/keepalived.log"
   ```