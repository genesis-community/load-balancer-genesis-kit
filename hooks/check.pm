#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Check::LoadBalancer v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{ok} = 1; # Start assuming all checks will pass
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Check load balancer configuration
  $env->notify("checking load balancer configuration...");

  # Validate load_balancers param exists
  my $load_balancers = $env->lookup('params.load_balancers');
  if (!$load_balancers || ref($load_balancers) ne 'ARRAY' || scalar(@$load_balancers) == 0) {
    $env->notify(error => "no load balancers defined in params.load_balancers! [#R{FAILED}]");
    $self->{ok} = 0;
  } else {
    $env->notify(success => "found " . scalar(@$load_balancers) . " load balancer(s) defined. [#G{OK}]");

    # Check each load balancer configuration
    foreach my $lb (@$load_balancers) {
      if (!$lb->{name}) {
        $env->notify(error => "load balancer missing required 'name' field! [#R{FAILED}]");
        $self->{ok} = 0;
      }

      if (!$lb->{mode}) {
        $env->notify(error => "load balancer '$lb->{name}' missing required 'mode' field! [#R{FAILED}]");
        $self->{ok} = 0;
      }

      if (!$lb->{port}) {
        $env->notify(error => "load balancer '$lb->{name}' missing required 'port' field! [#R{FAILED}]");
        $self->{ok} = 0;
      }

      if (!$lb->{backend} || !$lb->{backend}->{addresses} || ref($lb->{backend}->{addresses}) ne 'ARRAY' || scalar(@{$lb->{backend}->{addresses}}) == 0) {
        $env->notify(error => "load balancer '$lb->{name}' missing or has empty backend addresses! [#R{FAILED}]");
        $self->{ok} = 0;
      }
    }
  }

  # Check vm_type parameter
  my $vm_type = $env->lookup('params.vm_type');
  if (!$vm_type) {
    $env->notify(error => "missing required params.vm_type! [#R{FAILED}]");
    $self->{ok} = 0;
  } else {
    $env->notify(success => "vm_type configured to '$vm_type'. [#G{OK}]");
  }

  # Check network parameter
  my $network = $env->lookup('params.haproxy_network');
  if (!$network) {
    $env->notify(error => "missing required params.haproxy_network! [#R{FAILED}]");
    $self->{ok} = 0;
  } else {
    $env->notify(success => "haproxy_network configured to '$network'. [#G{OK}]");
  }

  # Return the final result
  if ($self->{ok}) {
    $env->notify(success => "all checks passed. [#G{OK}]");
  } else {
    $env->notify(error => "some checks failed! [#R{FAILED}]");
  }

  return $self->done($self->{ok});
}

1;

