#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::LoadBalancer v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Validate and add features
  my $type_feature_count = 0;

  foreach my $feature (@{$self->{features}}) {
    if ($feature eq 'vip') {
      $self->add_feature($feature);
    } elsif ($feature eq 'static-ips') {
      $self->add_feature($feature);
    } elsif ($feature eq 'cf') {
      $type_feature_count++;
      $self->add_feature($feature);
    } else {
      bail(
        "Feature '%s' not supported in this kit. Supported features are: vip, static-ips, cf",
        $feature
      );
    }
  }

  # Check if more than one type feature was enabled
  if ($type_feature_count > 1) {
    bail(
      "You have enabled more than one load-balancer 'type' feature flag."
    );
  }

  return $self->done();
}

1;

