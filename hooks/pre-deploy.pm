#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PreDeploy::LoadBalancer v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";
use Time::HiRes qw/gettimeofday/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Get the manifest and vars file paths from the environment
  my $manifest_path = $ENV{GENESIS_MANIFEST_FILE};
  my $vars_file = $ENV{GENESIS_BOSHVARS_FILE};

  if (!$manifest_path || !-f $manifest_path) {
    bail("Cannot find manifest file at '$manifest_path'");
  }

  # Validate load balancer configuration
  $env->notify("validating load balancer configuration...");

  # Get load balancers from the environment
  my $load_balancers = $env->lookup('params.load_balancers');
  if (!$load_balancers || ref($load_balancers) ne 'ARRAY' || scalar(@$load_balancers) == 0) {
    bail("No load balancers defined in params.load_balancers");
  }

  info("Found %d load balancer(s) configured.", scalar(@$load_balancers));

  # Check if static IPs are configured when static-ips feature is enabled
  if ($env->has_feature('static-ips')) {
    my $static_ips = $env->lookup('params.static_ips');
    if (!$static_ips || ref($static_ips) ne 'ARRAY' || scalar(@$static_ips) == 0) {
      bail("static-ips feature is enabled but no static_ips are defined in params");
    }

    info("Found %d static IP(s) configured for load balancer(s).", scalar(@$static_ips));
  }

  # Validate certificate configuration when TLS is configured
  foreach my $lb (@$load_balancers) {
    if ($lb->{tls} && $lb->{tls}->{certificates}) {
      my $certificates = $lb->{tls}->{certificates};
      if (ref($certificates) ne 'ARRAY' || scalar(@$certificates) == 0) {
        bail("Load balancer '%s' has TLS enabled but no certificates configured", $lb->{name});
      }

      info("Load balancer '%s' has %d TLS certificate(s) configured.",
           $lb->{name}, scalar(@$certificates));
    }
  }

  # Everything looks good
  $env->notify(success => "pre-deployment validation passed.");

  # Pre-deployment data to be passed to post-deploy hook
  return $self->done({
    'load_balancers' => scalar(@$load_balancers),
    'timestamp' => time()
  });
}

1;

