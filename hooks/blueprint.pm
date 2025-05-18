#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Blueprint::LoadBalancer v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{files} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($blueprint) = @_; # $blueprint is '$self'

  # Add base manifest files
  $blueprint->add_files(
    "manifests/load-balancer.yml",
    "manifests/releases/load-balancer.yml"
  );

  # Check for vip feature
  if ($blueprint->want_feature('vip')) {
    $blueprint->add_files("manifests/keepalived.yml");
  }

  # Check for static-ips feature
  if ($blueprint->want_feature('static-ips')) {
    $blueprint->add_files("manifests/static.yml");
  }

  # Track how many types features are enabled
  my $types = 0;

  # Check for CF feature
  if ($blueprint->want_feature('cf')) {
    $types++;
    $blueprint->add_files("manifests/types/cf.yml");
  }

  # If more than one load-balancer type is enabled, that's an error
  if ($types > 1) {
    bail(
      "You have enabled more than one load-balancer 'type' feature flag."
    );
  }

  return $blueprint->done();
}

1;

