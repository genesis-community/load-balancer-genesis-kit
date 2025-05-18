#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::LoadBalancer::Status v1.0.0;

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
  return
  "Display the current status of the load balancer instances.\n".
  "This will show VM health, port status, and current connections.\n".
  "Supports the following options:\n".
  "[[  #y{--detailed}         >>Show detailed statistics and metrics\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Parse options
  my %options = $self->parse_options([
    'detailed',  # Show detailed status information
  ]);

  # Get the deployment name
  my $deployment_name = $env->deployment_name;

  # Check if the deployment exists
  my ($out, $rc, $err) = run({ stderr => 0 },
                            'bosh -d "$1" instances --ps',
                            $deployment_name);

  if ($rc != 0) {
    bail("Failed to get BOSH deployment information: %s", $err || "Unknown error");
  }

  info("\n#B{Load Balancer Status}\n\n");
  info("Deployment: #G{%s}\n\n", $deployment_name);

  # Show basic deployment status
  info("%s\n", $out);

  # If detailed option is provided, show more information
  if ($options{detailed}) {
    # Get VM details
    ($out, $rc, $err) = run({ stderr => 0 },
                           'bosh -d "$1" instances --details',
                           $deployment_name);

    if ($rc != 0) {
      bail("Failed to get detailed VM information: %s", $err || "Unknown error");
    }

    info("\n#B{Detailed VM Information}\n\n");
    info("%s\n", $out);

    # Get HAProxy statistics if possible
    info("\n#B{HAProxy Statistics}\n\n");

    # Try to execute BOSH SSH command to get HAProxy stats
    ($out, $rc, $err) = run({ stderr => 0 },
                          'bosh -d "$1" ssh haproxy/0 "echo show stat | socat unix-connect:/var/vcap/sys/run/haproxy/haproxy.sock stdio" 2>/dev/null',
                          $deployment_name);

    if ($rc == 0 && $out) {
      info("HAProxy statistics retrieved successfully:\n\n");
      info("%s\n", $out);
    } else {
      info("Could not retrieve HAProxy statistics. This may be due to:\n");
      info("  - The deployment is not running HAProxy\n");
      info("  - SSH access is not configured\n");
      info("  - HAProxy status socket is not accessible\n\n");
    }
  }

  # Show available load balancer endpoints
  my $load_balancers = $env->lookup('params.load_balancers') || [];

  if (@$load_balancers) {
    info("\n#B{Load Balancer Endpoints}\n\n");

    foreach my $lb (@$load_balancers) {
      my $protocol = ($lb->{tls}) ? 'https' : 'http';
      my $port = $lb->{port} || ($protocol eq 'https' ? 443 : 80);

      info("  - #G{%s}: #C{%s://<load-balancer-ip>:%d}\n",
           $lb->{name}, $protocol, $port);
    }
    info("\n");
  }

  return $self->done(1);
}

1;

