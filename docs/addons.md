# Addons Guide

The Load Balancer Genesis Kit provides several addon commands to help manage and operate your deployment. This guide explains each addon in detail.

## Available Addons

The following addons are available:

- `cf` - Configure load balancers interactively
- `rc` - Generate and upload runtime configs for HAProxy metrics
- `st` - View detailed status of your load balancer

## `cf` - Configure Load Balancers

The `cf` addon provides an interactive interface for configuring load balancers in your environment without manually editing the environment file.

### Usage

```bash
genesis do my-env -- cf [--reset]
```

### Options

- `--reset` - Reset the load balancer configuration to defaults

### Examples

#### Basic Usage

```bash
genesis do my-env -- cf
```

This will display a menu with the following options:
- Add a new load balancer
- Modify an existing load balancer
- Remove a load balancer
- Exit without changes

#### Reset Configuration

```bash
genesis do my-env -- cf --reset
```

This will reset the load balancer configuration to default settings after confirming with you.

### Workflow

#### Adding a Load Balancer

When adding a new load balancer, you will be prompted for:
1. Name for the load balancer
2. Mode (HTTP or TCP)
3. Port number
4. Whether to enable TLS
5. Backend addresses

#### Modifying a Load Balancer

When modifying a load balancer, you can:
1. Change the name
2. Change the mode (HTTP or TCP)
3. Change the port number
4. Enable or disable TLS
5. Modify backend addresses (add, remove, or replace)

#### Removing a Load Balancer

When removing a load balancer, you will:
1. Select which load balancer to remove
2. Confirm the deletion

### Implementation Details

The `cf` addon works by:
1. Reading the current environment file
2. Parsing the load balancer configuration
3. Making changes based on your input
4. Writing the changes back to the environment file

## `rc` - Generate Runtime Config

The `rc` addon generates a BOSH runtime config for the HAProxy metrics agent, which can be used to collect metrics from your load balancer instances.

### Usage

```bash
genesis do my-env -- rc [--upload]
```

### Options

- `--upload` - Upload the generated runtime config to the BOSH director

### Examples

#### Generate Runtime Config

```bash
genesis do my-env -- rc
```

This will generate a runtime config and save it to a file, but will not upload it to the BOSH director.

#### Generate and Upload Runtime Config

```bash
genesis do my-env -- rc --upload
```

This will generate a runtime config, save it to a file, and upload it to the BOSH director.

### Runtime Config Contents

The generated runtime config includes:
- The HAProxy release
- The HAProxy metrics agent job configuration
- Stemcell inclusion criteria
- Agent properties for metrics collection

The metrics agent will be deployed to all VMs with compatible stemcells, allowing you to collect HAProxy metrics.

### Using with Prometheus

The HAProxy metrics agent is compatible with Prometheus. To use it with Prometheus:

1. Generate and upload the runtime config:
   ```bash
   genesis do my-env -- rc --upload
   ```

2. Configure Prometheus to scrape metrics from port 9100 on your HAProxy instances.

3. Import the HAProxy dashboard into Grafana for visualization.

## `st` - Display Status

The `st` addon provides information about the current status of your load balancer deployment.

### Usage

```bash
genesis do my-env -- st [--detailed]
```

### Options

- `--detailed` - Show detailed statistics and metrics

### Examples

#### Basic Status

```bash
genesis do my-env -- st
```

This will show:
- BOSH deployment information
- Load balancer configuration
- Instance status

#### Detailed Status

```bash
genesis do my-env -- st --detailed
```

This will show all of the basic information plus:
- Detailed VM information
- HAProxy statistics (if available)
- Process status

### Implementation Details

The `st` addon works by:
1. Querying the BOSH director for deployment information
2. Retrieving HAProxy statistics if possible
3. Formatting and displaying the information

For detailed statistics, it attempts to connect to the HAProxy statistics socket to retrieve real-time metrics.

## Common Tasks with Addons

### Initial Setup

```bash
# Deploy the environment
genesis deploy my-env

# Check the status
genesis do my-env -- st
```

### Configuring Load Balancers

```bash
# Interactive configuration
genesis do my-env -- cf

# Deploy the changes
genesis deploy my-env
```

### Monitoring and Metrics

```bash
# Enable metrics collection
genesis do my-env -- rc --upload

# Check detailed status including metrics
genesis do my-env -- st --detailed
```

### Troubleshooting

```bash
# Check detailed status
genesis do my-env -- st --detailed

# Reset configuration if needed
genesis do my-env -- cf --reset

# Redeploy after changes
genesis deploy my-env
```

## Extending Addons

The Load Balancer Genesis Kit can be extended with additional addons. To create a new addon, add a Perl module to the `hooks/` directory with a name pattern of `addon-NAME~SHORTNAME.pm`.

Example addon structure:
```perl
#!/usr/bin/env perl
package Genesis::Hook::Addon::LoadBalancer::NewAddon v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return "Description of your new addon.\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  
  # Your addon code here
  
  return $self->done(1);
}

1;
```