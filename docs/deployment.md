# Deployment Guide

This guide provides step-by-step instructions for deploying the Load Balancer Genesis Kit in various configurations.

## Prerequisites

- BOSH Director with cloud-config configured
- Genesis v2.6.0 or later
- Access to a Vault instance (for storing certificates and credentials)

## Basic Deployment

1. Create a new deployment repository:
   ```bash
   genesis init --kit load-balancer
   cd load-balancer-deployments
   ```

2. Create a new environment file:
   ```bash
   genesis new site
   ```

3. Edit the environment file to configure your load balancer:
   ```yaml
   kit:
     name: load-balancer
     version: 0.0.1

   params:
     load_balancers:
     - name: web-lb
       mode: http
       port: 80
       backend:
         addresses:
           - 10.0.0.10:8080
           - 10.0.0.11:8080
     haproxy_network: default
     vm_type: default
   ```

4. Deploy the environment:
   ```bash
   genesis deploy site
   ```

## Deploying with High Availability (VIP)

1. Create an environment with the `vip` feature:
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
     - name: ha-web-lb
       mode: http
       port: 80
       backend:
         addresses:
           - 10.0.0.10:8080
           - 10.0.0.11:8080
     haproxy_network: default
     vm_type: default
   ```

2. Deploy the environment:
   ```bash
   genesis deploy site
   ```

## Deploying for Cloud Foundry

1. Create an environment with the `cf` feature:
   ```yaml
   kit:
     name: load-balancer
     version: 0.0.1

   features:
     - cf

   params:
     cf-deployment: site-cf
     certificates:
       - ((vault "secret/site/ssl:certificate"))
     haproxy_network: default
     vm_type: default
   ```

2. Deploy the environment:
   ```bash
   genesis deploy site
   ```

## Multiple Load Balancers

You can configure multiple load balancers in a single deployment:

```yaml
kit:
  name: load-balancer
  version: 0.0.1

params:
  load_balancers:
  - name: http-frontend
    mode: http
    port: 80
    backend:
      addresses:
        - 10.0.0.10:8080
        - 10.0.0.11:8080
  
  - name: api-frontend
    mode: http
    port: 8443
    tls:
      certificates:
      - ((vault "secret/site/api-ssl:certificate"))
    backend:
      addresses:
        - 10.0.0.20:8080
        - 10.0.0.21:8080
  
  - name: tcp-service
    mode: tcp
    port: 5432
    backend:
      addresses:
        - 10.0.0.30:5432
  
  haproxy_network: default
  vm_type: default
```

## Upgrading Your Deployment

To upgrade to a newer version of the Load Balancer Genesis Kit:

1. Update the kit version in your environment file:
   ```yaml
   kit:
     name: load-balancer
     version: 0.0.2  # New version
   ```

2. Redeploy the environment:
   ```bash
   genesis deploy site
   ```

## Scaling Your Deployment

To scale your load balancer horizontally:

```yaml
kit:
  name: load-balancer
  version: 0.0.1

params:
  instances: 3  # Deploy 3 instances for more capacity
  load_balancers:
  - name: web-lb
    mode: http
    port: 80
    backend:
      addresses:
        - 10.0.0.10:8080
        - 10.0.0.11:8080
  haproxy_network: default
  vm_type: default
```

To scale your load balancer vertically:

```yaml
kit:
  name: load-balancer
  version: 0.0.1

params:
  cpu: 4         # Allocate more CPU
  ram: 8192      # Allocate more RAM (in MB)
  disk: 32768    # Allocate more disk space (in MB)
  load_balancers:
  - name: web-lb
    mode: http
    port: 80
    backend:
      addresses:
        - 10.0.0.10:8080
        - 10.0.0.11:8080
  haproxy_network: default
  vm_type: default
```

## Interactive Configuration

After deploying your load balancer, you can use the interactive configuration addon to modify load balancers without editing the environment file directly:

```bash
genesis do site -- cf
```

This will display a menu that allows you to:
- Add new load balancers
- Modify existing load balancers
- Remove load balancers
- Reset to default configuration