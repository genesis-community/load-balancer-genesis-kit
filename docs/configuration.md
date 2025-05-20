# Configuration Guide

This guide provides detailed information about configuring the Load Balancer Genesis Kit.

## Environment Configuration Structure

Your environment file should follow this general structure:

```yaml
kit:
  name: load-balancer
  version: 0.0.1

# Optional features
features:
  - feature1
  - feature2

# Required and optional parameters
params:
  # Core configuration
  # Load balancer configurations
  # Feature-specific parameters
```

## Features

Features enable specific capabilities in the Load Balancer Genesis Kit. Features are specified in the `features` section of your environment file:

```yaml
features:
  - vip
  - static-ips
```

### Available Features

- **vip**: Enables high availability with keepalived and a virtual IP address
- **static-ips**: Enables the use of static IP addresses for load balancer VMs
- **cf**: Configures the load balancer for Cloud Foundry integration

Note: You can only use one 'type' feature at a time (currently only `cf` is a type feature).

## Core Parameters

These parameters are applicable to all deployments regardless of which features are enabled:

### VM Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `vm_type` | BOSH VM type to use (must exist in cloud-config) | `default` |
| `network` | Network to deploy HAProxy into (must exist in cloud-config) | `default` |
| `instances` | Number of HAProxy instances to deploy | `2` |
| `availability_zones` | Which AZs to deploy to | `[z1]` |
| `cpu` | CPU allocation for each VM | `2` |
| `ram` | RAM allocation in MB for each VM | `2048` |
| `disk` | Disk allocation in MB for each VM | `16384` |
| `stemcell_os` | The stemcell OS to use | `ubuntu-xenial` |
| `stemcell_version` | The stemcell version to use | `latest` |

### HAProxy Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `advanced_haproxy_config` | Raw HAProxy configuration to include | `null` |
| `load_balancers` | Array of load balancer configurations | *Required* |

## Load Balancer Configuration

Each entry in the `load_balancers` array can have the following properties:

### Basic Configuration

| Parameter | Description | Required |
|-----------|-------------|----------|
| `name` | Name for this load balancer | Yes |
| `mode` | Either `http` or `tcp` | Yes |
| `port` | Port to listen on | Yes |
| `redirect_to_https` | If "all", redirects HTTP to HTTPS (HTTP mode only) | No |

### TLS Configuration

TLS configuration is specified in the `tls` section of a load balancer:

| Parameter | Description | Required |
|-----------|-------------|----------|
| `certificates` | Array of certificate references | Yes (for TLS) |
| `protocols` | Array of TLS protocols to enable | No |
| `ciphers` | Array of ciphers to enable | No |

Example:
```yaml
tls:
  certificates:
    - ((vault "secret/site/ssl:certificate"))
  protocols:
    - tlsv1.2
    - tlsv1.3
  ciphers:
    - ECDHE-ECDSA-AES128-GCM-SHA256
    - ECDHE-RSA-AES128-GCM-SHA256
```

### Access Control Lists (ACLs)

ACLs are specified in the `acls` section of a load balancer:

| Parameter | Description | Required |
|-----------|-------------|----------|
| `name` | Name for the ACL | Yes |
| `allow` | Array of IPs/CIDRs to allow | No |
| `deny` | Array of IPs/CIDRs to deny | No |

Example:
```yaml
acls:
  - name: internal-only
    allow:
      - 10.0.0.0/8
      - 192.168.0.0/16
    deny:
      - 0.0.0.0/0
```

### Backend Configuration

Backend configuration is specified in the `backend` section of a load balancer:

| Parameter | Description | Required |
|-----------|-------------|----------|
| `addresses` | Array of backend addresses (format: IP:PORT) | Yes* |
| `link` | BOSH link to consume (alternative to addresses) | Yes* |
| `port` | Port for the backend if using a link | No |

*Either `addresses` or `link` must be provided, but not both.

Example with addresses:
```yaml
backend:
  addresses:
    - 10.0.0.10:8080
    - 10.0.0.11:8080
```

Example with link:
```yaml
backend:
  link: gorouter
  port: 80
```

## Feature-Specific Parameters

### VIP Feature

When the `vip` feature is enabled, the following parameters are required:

| Parameter | Description | Required |
|-----------|-------------|----------|
| `virtual-router-id` | VRRP Virtual Router ID (0-255) | Yes |
| `virtual-ip` | VRRP Virtual IPv4 Address | Yes |

Example:
```yaml
features:
  - vip

params:
  virtual-router-id: 42
  virtual-ip: 10.0.10.10
```

### Static IPs Feature

When the `static-ips` feature is enabled, the following parameter is required:

| Parameter | Description | Required |
|-----------|-------------|----------|
| `ips` | Array of static IP addresses | Yes |

Example:
```yaml
features:
  - static-ips

params:
  ips:
    - 10.0.0.10
    - 10.0.0.11
```

### Cloud Foundry Feature

When the `cf` feature is enabled, the following parameters are available:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `cf-deployment` | Name of the CF deployment to integrate with | `<env>-cf` |
| `allow-to-internal` | CIDR range to allow to internal CF components | `0.0.0.0/0` |
| `gorouter-http-port` | HTTP port for the gorouter | `80` |
| `gorouter-ssh-port` | SSH port for the gorouter | `2222` |
| `certificates` | Array of certificates for HTTPS | *Required* |
| `protocols` | TLS protocols to enable | *See default list in manifests* |
| `ciphers` | TLS ciphers to enable | *See default list in manifests* |

Example:
```yaml
features:
  - cf

params:
  cf-deployment: site-cf
  certificates:
    - ((vault "secret/site/ssl:certificate"))
```

## Advanced HAProxy Configuration

For advanced HAProxy configurations that aren't covered by the Genesis Kit parameters, you can use the `advanced_haproxy_config` parameter:

```yaml
params:
  advanced_haproxy_config: |
    maxconn 10000
    timeout connect 10s
    timeout client 30s
    timeout server 30s
    stats socket /var/vcap/sys/run/haproxy/haproxy.sock mode 600 level admin
```

## Certificate Management

HAProxy requires certificates in PEM format. If you're using Vault, make sure your certificates are stored in the correct format.

Example Vault entry with combined certificate and key:
```
certificate: |
  -----BEGIN CERTIFICATE-----
  MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiIMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
  BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
  ...
  -----END CERTIFICATE-----
private_key: |
  -----BEGIN PRIVATE KEY-----
  MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDFNXbj8eJX7/Oi
  FSNuzKpdeuL4MXg2N5/Th1zZZJJz8sBzPmPQ+ldj3lvT8sdQ/DiSVPcVQs8YXW6h
  ...
  -----END PRIVATE KEY-----
combined: |
  -----BEGIN CERTIFICATE-----
  MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiIMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
  BAYTAkFVMRMwEQYDVQQIDApTb21lLVN0YXRlMSEwHwYDVQQKDBhJbnRlcm5ldCBX
  ...
  -----END CERTIFICATE-----
  -----BEGIN PRIVATE KEY-----
  MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQDFNXbj8eJX7/Oi
  FSNuzKpdeuL4MXg2N5/Th1zZZJJz8sBzPmPQ+ldj3lvT8sdQ/DiSVPcVQs8YXW6h
  ...
  -----END PRIVATE KEY-----
```

In your load balancer configuration, reference the `combined` field:

```yaml
tls:
  certificates:
    - ((vault "secret/site/ssl:combined"))
```