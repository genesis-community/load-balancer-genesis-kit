#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Info::LoadBalancer v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info run/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Get BOSH deployment info
  my ($out, $rc, $err) = run({ stderr => 0 },
                            'bosh -d "$1" instances --ps',
                            $env->deployment_name);

  if ($rc != 0) {
    bail("Failed to get BOSH deployment information: %s", $err || "Unknown error");
  }

  # Display BOSH deployment info
  info("\n#B{BOSH Deployment Information}\n\n%s\n", $out);

  # Get load balancer configuration
  my $load_balancers = $env->lookup('params.load_balancers') || [];

  # Display load balancer info
  info("#B{Load Balancer Configuration}\n");

  if (@$load_balancers) {
    foreach my $lb (@$load_balancers) {
      my $protocol = ($lb->{tls}) ? 'https' : 'http';
      my $port = $lb->{port} || ($protocol eq 'https' ? 443 : 80);

      info("Load Balancer: #G{%s}\n", $lb->{name});
      info("  Mode: #C{%s}\n", $lb->{mode} || 'http');
      info("  Port: #C{%d}\n", $port);

      # Display backend addresses
      if ($lb->{backend} && $lb->{backend}->{addresses}) {
        info("  Backend Addresses:\n");
        foreach my $addr (@{$lb->{backend}->{addresses}}) {
          info("    - #C{%s}\n", $addr);
        }
      }

      # Display ACLs if configured
      if ($lb->{acls} && @{$lb->{acls}}) {
        info("  ACLs:\n");
        foreach my $acl (@{$lb->{acls}}) {
          info("    - #C{%s}:\n", $acl->{name});

          if ($acl->{allow} && @{$acl->{allow}}) {
            info("      Allow:\n");
            foreach my $allow (@{$acl->{allow}}) {
              info("        - #C{%s}\n", $allow);
            }
          }

          if ($acl->{deny} && @{$acl->{deny}}) {
            info("      Deny:\n");
            foreach my $deny (@{$acl->{deny}}) {
              info("        - #C{%s}\n", $deny);
            }
          }
        }
      }

      # Display TLS info if configured
      if ($lb->{tls}) {
        info("  TLS: #G{Enabled}\n");

        if ($lb->{tls}->{certificates}) {
          info("  Certificates:\n");
          foreach my $cert (@{$lb->{tls}->{certificates}}) {
            info("    - #C{%s}\n", $cert);
          }
        }
      } else {
        info("  TLS: #R{Disabled}\n");
      }

      info("\n");
    }
  } else {
    info("  No load balancers configured.\n\n");
  }

  # Display VIP information if applicable
  if ($env->has_feature('vip')) {
    my $vip = $env->lookup('params.vip');
    if ($vip) {
      info("#B{Virtual IP (VIP)}\n\n  #C{%s}\n\n", $vip);
    } else {
      info("#B{Virtual IP (VIP)}\n\n  Not configured\n\n");
    }
  }

  # Display static IPs if applicable
  if ($env->has_feature('static-ips')) {
    my $static_ips = $env->lookup('params.static_ips') || [];
    info("#B{Static IPs}\n\n");

    if (@$static_ips) {
      foreach my $ip (@$static_ips) {
        info("  - #C{%s}\n", $ip);
      }
      info("\n");
    } else {
      info("  No static IPs configured.\n\n");
    }
  }

  # Display addon information
  info("#B{Available Addons}\n\n");
  info("  Run #G{%s do} to see available commands for this deployment.\n\n",
       $env->get_call_path_with_env);

  return $self->done(1);
}

1;

