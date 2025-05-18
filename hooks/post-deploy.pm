#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::LoadBalancer v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/info/;
use parent qw(Genesis::Hook::PostDeploy);
use lib $ENV{GENESIS_LIB} // "$ENV{HOME}/.genesis/lib";
use Time::HiRes qw/gettimeofday/;
use JSON::PP;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Get pre-deploy data if available
  my $pre_deploy_data = {};
  if ($self->{data}) {
    eval {
      $pre_deploy_data = decode_json($self->{data});
    };
    if ($@) {
      info("Warning: Could not parse pre-deploy data: $@");
    }
  }

  # Only proceed with helpful information if deployment was successful
  if ($self->deploy_successful) {
    # Get load balancer configuration
    my $load_balancers = $env->lookup('params.load_balancers') || [];
    my $lb_count = scalar(@$load_balancers);

    # Get VIP information if applicable
    my $vip_info = '';
    if ($env->has_feature('vip')) {
      my $vip = $env->lookup('params.vip');
      $vip_info = $vip ? "\nVirtual IP (VIP): #C{$vip}\n" : '';
    }

    # Get static IPs if applicable
    my $static_ips_info = '';
    if ($env->has_feature('static-ips')) {
      my $static_ips = $env->lookup('params.static_ips') || [];
      if (@$static_ips) {
        $static_ips_info = "\nStatic IPs:\n";
        foreach my $ip (@$static_ips) {
          $static_ips_info .= "  - #C{$ip}\n";
        }
      }
    }

    # Compile load balancer endpoints information
    my $endpoints_info = "\nLoad Balancer Endpoints:\n";
    foreach my $lb (@$load_balancers) {
      my $protocol = ($lb->{tls}) ? 'https' : 'http';
      my $port = $lb->{port} || ($protocol eq 'https' ? 443 : 80);

      $endpoints_info .= sprintf("  - #G{%s}: #C{%s://<load-balancer-ip>:%d}\n",
                                 $lb->{name}, $protocol, $port);
    }

    # Display deployment information
    info(
      "\n#M{$ENV{GENESIS_ENVIRONMENT}} Load Balancer successfully deployed!\n".
      "\nDeployed %d load balancer(s)%s\n".
      "%s%s".
      "\nFor detailed information, run:\n".
      "\t#G{%s info}\n",
      $lb_count,
      $pre_deploy_data->{load_balancers} ? " (previously: $pre_deploy_data->{load_balancers})" : "",
      $vip_info,
      $endpoints_info,
      $env->get_call_path_with_env
    );
  } else {
    info("\n#R{Deployment failed!} Please check the output for errors.\n");
  }

  return $self->done(1);
}

1;

