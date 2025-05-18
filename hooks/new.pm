#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::New::LoadBalancer v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/run info/;
use Genesis::UI qw/prompt_for_boolean/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{features} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Create the environment file with default configuration
  my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";
  open my $fh, ">>", $env_file or die "Cannot open $env_file for writing: $!";

  print $fh <<EOF;
kit:
  name:    $ENV{GENESIS_KIT_NAME}
  version: $ENV{GENESIS_KIT_VERSION}

params:
  load_balancers:
  - name: front-door # ---------- an EXAMPLE load balancer
    mode: http       #            you can have lots of these...
    port: 443
    acls:
    - name: allow-internal
      allow:
        - 10.0.0.0/8
    backend:
      addresses:
        - 10.2.1.1

    tls:
      certificates: ~
  advanced_haproxy_config: null
  haproxy_network: default
  vm_type: default
EOF

  close $fh;

  # Offer environment editor
  run({ interactive => 1 }, 'offer_environment_editor');

  return $self->done(1);
}

1;

