# Load Balancer Genesis Kit

The Load Balancer Genesis Kit provides a comprehensive solution for deploying HAProxy-based load balancers for your BOSH deployments. It is designed to provide flexible, highly-available load balancing for Cloud Foundry and other applications.

## Key Features

- **HAProxy Configuration**: Deploy HAProxy with custom configs and backends
- **High Availability**: Optional VIP support with failover via keepalived
- **Access Control**: Configure ACLs to control access to your applications
- **TLS Support**: Terminate TLS connections with custom certificates
- **Cloud Foundry Integration**: Seamlessly integrate with Cloud Foundry deployments

## Prerequisites

- BOSH Director
- Genesis v2.6.0 or later
- Access to the public internet (or a suitable blobstore mirror)

## Quick Start

To use the kit, you don't even need to clone this repository! Just run:

```bash
# Create a load-balancer-deployments repo using the latest version of the kit
genesis init --kit load-balancer

# Create a load-balancer-deployments repo using v1.0.0 of the kit
genesis init --kit load-balancer/1.0.0

# Create a my-load-balancer-configs repo using the latest version of the kit
genesis init --kit load-balancer -d my-load-balancer-configs
```

Once created, refer to the deployment repository README for information on
provisioning and deploying new environments.

## Deployment

After initializing your deployment repository, you can create and deploy environments:

```bash
# Create a new environment file for a site
cd my-load-balancer-configs
genesis new site

# Deploy the environment
genesis deploy my-site

# Run the info addon to see details about your deployment
genesis do my-site -- info
```

## Available Features

- **vip**: Deploy with a VIP for high availability
- **static-ips**: Use static IPs for load balancer instances
- **cf**: Configure for Cloud Foundry integration

## Available Addons

- **cf**: Configure load balancers interactively
- **rc**: Generate and upload runtime configs for HAProxy
- **st**: View detailed status of your load balancer

## Documentation

For more detailed documentation, see:

- [Load Balancer Genesis Kit Manual](MANUAL.md)
- [Deployment Guide](docs/deployment.md)
- [Configuration Guide](docs/configuration.md)
- [Operations Guide](docs/operations.md)