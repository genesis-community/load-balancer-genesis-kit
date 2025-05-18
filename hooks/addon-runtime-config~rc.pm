#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::LoadBalancer::RuntimeConfig v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use parent qw(Genesis::Hook::Addon);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";
use File::Basename qw/basename/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Generates a BOSH runtime config for load balancer plugins.\n".
  "This can be used to deploy load balancer agents to all VMs in a BOSH deployment.\n".
  "Supports the following options:\n".
  "[[  #y{--upload}           >>Upload the generated runtime config to the BOSH director";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Parse options
  my %options = $self->parse_options([
    'upload',  # Upload the runtime config to the BOSH director
  ]);

  # Generate runtime config
  my $runtime_config = <<EOF;
releases:
  - name: haproxy
    version: 11.10.0
    url: https://bosh.io/d/github.com/cloudfoundry-incubator/haproxy-boshrelease?v=11.10.0
    sha1: 1b3f455672b25be29b20485ba480e0b60fbf6e9f

addons:
  - name: haproxy-agent
    jobs:
      - name: haproxy_metrics_agent
        release: haproxy
    include:
      stemcell:
        - os: ubuntu-jammy
        - os: ubuntu-bionic
        - os: ubuntu-xenial
    properties:
      haproxy_metrics_agent:
        enable: true
        target: localhost:9100  # assumes node_exporter is running
EOF

  # Display the generated runtime config
  info("\n#B{Generated Runtime Config}\n\n%s\n", $runtime_config);

  # Save the runtime config to a file
  my $runtime_config_file = $env->workpath("haproxy-runtime-config.yml");
  open my $fh, '>', $runtime_config_file or bail("Cannot open $runtime_config_file for writing: $!");
  print $fh $runtime_config;
  close $fh;

  info("Runtime config saved to: #C{%s}\n\n", $runtime_config_file);

  # Upload the runtime config if requested
  if ($options{upload}) {
    info("Uploading runtime config to BOSH director...\n");

    # Get BOSH environment
    my $bosh = $env->bosh;

    my ($out, $rc, $err) = $bosh->execute(
      'update-runtime-config "$1" --name=haproxy-metrics',
      $runtime_config_file
    );

    if ($rc != 0) {
      bail("Failed to upload runtime config: %s", $err || $out);
    }

    info("\n#G{Runtime config successfully uploaded to BOSH director.}\n\n");

    info("You can verify the runtime config with:\n");
    info("  #C{bosh runtime-config --name=haproxy-metrics}\n\n");
  } else {
    info("To upload this runtime config to your BOSH director, run:\n");
    info("  #C{bosh update-runtime-config %s --name=haproxy-metrics}\n\n", $runtime_config_file);
  }

  return $self->done(1);
}

1;

