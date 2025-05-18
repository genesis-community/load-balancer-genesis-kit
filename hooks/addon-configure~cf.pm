#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::LoadBalancer::Configure v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20
use Genesis qw/bail info run/;
use Genesis::UI qw/prompt_for_boolean prompt_for/;
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
  "Interactively configure a load balancer in the environment manifest.\n".
  "This will allow you to add, modify, or remove load balancers from your deployment.\n".
  "Supports the following options:\n".
  "[[  #y{--reset}            >>Reset the load balancer configuration to defaults\n";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Parse options
  my %options = $self->parse_options([
    'reset',  # Reset the load balancer configuration
  ]);

  # Get the current environment file path
  my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";

  # Get current load balancers configuration
  my $load_balancers = $env->lookup('params.load_balancers') || [];

  # If reset option is provided, reset the configuration
  if ($options{reset}) {
    $self->_reset_configuration($env_file);
    return $self->done(1);
  }

  # Display current configuration
  info("\n#B{Current Load Balancer Configuration}\n\n");

  if (@$load_balancers) {
    foreach my $i (0..$#$load_balancers) {
      my $lb = $load_balancers->[$i];
      info("#G{Load Balancer %d}: #C{%s}\n", $i+1, $lb->{name});
      info("  Mode: #C{%s}\n", $lb->{mode} || 'http');
      info("  Port: #C{%d}\n", $lb->{port} || 80);
      info("\n");
    }
  } else {
    info("No load balancers currently configured.\n\n");
  }

  # Prompt for action
  my $action;
  prompt_for('action', 'select',
    'What would you like to do?',
    '-o "[add] Add a new load balancer"',
    '-o "[modify] Modify an existing load balancer"',
    '-o "[remove] Remove a load balancer"',
    '-o "[exit] Exit without changes"',
    \$action);

  if ($action eq 'add') {
    $self->_add_load_balancer($env_file, $load_balancers);
  } elsif ($action eq 'modify') {
    if (@$load_balancers) {
      $self->_modify_load_balancer($env_file, $load_balancers);
    } else {
      info("\n#R{No load balancers to modify.}\n\n");
    }
  } elsif ($action eq 'remove') {
    if (@$load_balancers) {
      $self->_remove_load_balancer($env_file, $load_balancers);
    } else {
      info("\n#R{No load balancers to remove.}\n\n");
    }
  } elsif ($action eq 'exit') {
    info("\n#G{Exiting without changes.}\n\n");
  }

  return $self->done(1);
}

sub _reset_configuration {
  my ($self, $env_file) = @_;

  my $confirm = prompt_for_boolean(
    "\nAre you sure you want to reset the load balancer configuration? This will replace your current configuration with defaults. [y|n]",
    0
  );

  if ($confirm) {
    # Read current file
    open my $in, '<', $env_file or bail("Cannot open $env_file for reading: $!");
    my @lines = <$in>;
    close $in;

    # Process file to replace load_balancers configuration
    open my $out, '>', $env_file or bail("Cannot open $env_file for writing: $!");
    my $in_lb_section = 0;
    my $written_lb = 0;

    foreach my $line (@lines) {
      if ($line =~ /^\s*load_balancers:/) {
        $in_lb_section = 1;
        print $out $line;
        print $out "  - name: front-door # ---------- default load balancer\n";
        print $out "    mode: http       #            you can have lots of these...\n";
        print $out "    port: 443\n";
        print $out "    acls:\n";
        print $out "    - name: allow-internal\n";
        print $out "      allow:\n";
        print $out "        - 10.0.0.0/8\n";
        print $out "    backend:\n";
        print $out "      addresses:\n";
        print $out "        - 10.2.1.1\n";
        print $out "    tls:\n";
        print $out "      certificates: ~\n";
        $written_lb = 1;
      } elsif ($in_lb_section && $line =~ /^\s*[a-zA-Z]/) {
        $in_lb_section = 0;
        print $out $line;
      } elsif ($in_lb_section && !$written_lb) {
        # Skip existing load balancer config
      } else {
        print $out $line;
      }
    }
    close $out;

    info("\n#G{Load balancer configuration has been reset to defaults.}\n\n");
  } else {
    info("\n#R{Reset cancelled.}\n\n");
  }
}

sub _add_load_balancer {
  my ($self, $env_file, $load_balancers) = @_;

  # Collect information for the new load balancer
  my $name;
  prompt_for('name', 'line',
    'Enter a name for the new load balancer:',
    '--validation nonempty', \$name);

  my $mode;
  prompt_for('mode', 'select',
    'Select the mode for this load balancer:',
    '-o "[http] HTTP/HTTPS mode"',
    '-o "[tcp] TCP mode"',
    \$mode);
  $mode =~ s/^\[(.*)\].*$/$1/;

  my $port;
  prompt_for('port', 'line',
    'Enter the port number:',
    '--validation number --default ' . ($mode eq 'http' ? '80' : '443'),
    \$port);

  my $use_tls = prompt_for_boolean(
    "Enable TLS (SSL) for this load balancer? [y|n]",
    $port == 443
  );

  # Collect backend addresses
  my @backend_addresses;
  info("\nEnter backend addresses (leave empty to finish):\n");

  my $address;
  do {
    $address = '';
    prompt_for('address', 'line',
      'Backend address:',
      '--default ""', \$address);

    push @backend_addresses, $address if $address;
  } while ($address);

  # Add at least one default address if none provided
  if (@backend_addresses == 0) {
    push @backend_addresses, '10.0.0.1';
  }

  # Create the new load balancer config
  my $new_lb = {
    name => $name,
    mode => $mode,
    port => $port,
    backend => {
      addresses => \@backend_addresses,
    },
  };

  # Add TLS configuration if enabled
  if ($use_tls) {
    $new_lb->{tls} = {
      certificates => [],
    };
  }

  # Add the new load balancer to the configuration
  push @$load_balancers, $new_lb;

  # Update the environment file
  $self->_update_env_file($env_file, $load_balancers);

  info("\n#G{New load balancer '$name' has been added.}\n\n");
}

sub _modify_load_balancer {
  my ($self, $env_file, $load_balancers) = @_;

  # Prompt for which load balancer to modify
  my @options;
  foreach my $i (0..$#$load_balancers) {
    push @options, "-o \"[$i] $load_balancers->[$i]->{name}\"";
  }

  my $index;
  prompt_for('index', 'select',
    'Which load balancer would you like to modify?',
    @options, \$index);
  $index =~ s/^\[(.*)\].*$/$1/;

  my $lb = $load_balancers->[$index];

  # Prompt for which field to modify
  my $field;
  prompt_for('field', 'select',
    "What would you like to modify for '$lb->{name}'?",
    '-o "[name] Name"',
    '-o "[mode] Mode (http/tcp)"',
    '-o "[port] Port number"',
    '-o "[backend] Backend addresses"',
    '-o "[tls] TLS configuration"',
    \$field);
  $field =~ s/^\[(.*)\].*$/$1/;

  if ($field eq 'name') {
    my $new_name;
    prompt_for('new_name', 'line',
      'Enter new name:',
      "--default \"$lb->{name}\" --validation nonempty", \$new_name);
    $lb->{name} = $new_name;
  } elsif ($field eq 'mode') {
    my $new_mode;
    prompt_for('new_mode', 'select',
      'Select the new mode:',
      '-o "[http] HTTP/HTTPS mode"',
      '-o "[tcp] TCP mode"',
      \$new_mode);
    $new_mode =~ s/^\[(.*)\].*$/$1/;
    $lb->{mode} = $new_mode;
  } elsif ($field eq 'port') {
    my $new_port;
    prompt_for('new_port', 'line',
      'Enter new port number:',
      "--default \"$lb->{port}\" --validation number", \$new_port);
    $lb->{port} = $new_port;
  } elsif ($field eq 'backend') {
    # Display current backend addresses
    info("\nCurrent backend addresses:\n");
    foreach my $addr (@{$lb->{backend}->{addresses}}) {
      info("  - #C{%s}\n", $addr);
    }

    # Prompt for action
    my $action;
    prompt_for('action', 'select',
      'What would you like to do with backend addresses?',
      '-o "[add] Add a new address"',
      '-o "[remove] Remove an address"',
      '-o "[replace] Replace all addresses"',
      \$action);
    $action =~ s/^\[(.*)\].*$/$1/;

    if ($action eq 'add') {
      my $new_addr;
      prompt_for('new_addr', 'line',
        'Enter new backend address:',
        '--validation nonempty', \$new_addr);
      push @{$lb->{backend}->{addresses}}, $new_addr;
    } elsif ($action eq 'remove') {
      if (@{$lb->{backend}->{addresses}} > 1) {
        my @options;
        foreach my $i (0..$#{$lb->{backend}->{addresses}}) {
          push @options, "-o \"[$i] $lb->{backend}->{addresses}->[$i]\"";
        }

        my $addr_index;
        prompt_for('addr_index', 'select',
          'Which address would you like to remove?',
          @options, \$addr_index);
        $addr_index =~ s/^\[(.*)\].*$/$1/;

        splice(@{$lb->{backend}->{addresses}}, $addr_index, 1);
      } else {
        info("\n#R{Cannot remove the only backend address. You must keep at least one.}\n\n");
      }
    } elsif ($action eq 'replace') {
      my @new_addresses;
      info("\nEnter new backend addresses (leave empty to finish):\n");

      my $address;
      do {
        $address = '';
        prompt_for('address', 'line',
          'Backend address:',
          '--default ""', \$address);

        push @new_addresses, $address if $address;
      } while ($address);

      if (@new_addresses > 0) {
        $lb->{backend}->{addresses} = \@new_addresses;
      } else {
        info("\n#R{You must provide at least one backend address.}\n\n");
      }
    }
  } elsif ($field eq 'tls') {
    my $currently_enabled = defined($lb->{tls}) ? 1 : 0;

    my $enable_tls = prompt_for_boolean(
      "Enable TLS for this load balancer? [y|n]",
      $currently_enabled
    );

    if ($enable_tls && !$currently_enabled) {
      $lb->{tls} = {
        certificates => [],
      };
      info("\n#G{TLS has been enabled.}\n\n");
    } elsif (!$enable_tls && $currently_enabled) {
      delete $lb->{tls};
      info("\n#G{TLS has been disabled.}\n\n");
    } else {
      info("\n#G{TLS configuration unchanged.}\n\n");
    }
  }

  # Update the environment file
  $self->_update_env_file($env_file, $load_balancers);

  info("\n#G{Load balancer '$lb->{name}' has been modified.}\n\n");
}

sub _remove_load_balancer {
  my ($self, $env_file, $load_balancers) = @_;

  # Prompt for which load balancer to remove
  my @options;
  foreach my $i (0..$#$load_balancers) {
    push @options, "-o \"[$i] $load_balancers->[$i]->{name}\"";
  }

  my $index;
  prompt_for('index', 'select',
    'Which load balancer would you like to remove?',
    @options, \$index);
  $index =~ s/^\[(.*)\].*$/$1/;

  my $lb_name = $load_balancers->[$index]->{name};

  my $confirm = prompt_for_boolean(
    "\nAre you sure you want to remove load balancer '$lb_name'? [y|n]",
    0
  );

  if ($confirm) {
    # Remove the selected load balancer
    splice(@$load_balancers, $index, 1);

    # Update the environment file
    $self->_update_env_file($env_file, $load_balancers);

    info("\n#G{Load balancer '$lb_name' has been removed.}\n\n");
  } else {
    info("\n#R{Removal cancelled.}\n\n");
  }
}

sub _update_env_file {
  my ($self, $env_file, $load_balancers) = @_;

  # Read current file
  open my $in, '<', $env_file or bail("Cannot open $env_file for reading: $!");
  my @lines = <$in>;
  close $in;

  # Process file to replace load_balancers configuration
  open my $out, '>', $env_file or bail("Cannot open $env_file for writing: $!");
  my $in_lb_section = 0;
  my $written_lb = 0;

  foreach my $line (@lines) {
    if ($line =~ /^\s*load_balancers:/) {
      $in_lb_section = 1;
      print $out $line;

      # Write the updated load balancers configuration
      foreach my $lb (@$load_balancers) {
        print $out "  - name: $lb->{name}\n";
        print $out "    mode: $lb->{mode}\n";
        print $out "    port: $lb->{port}\n";

        # Write backend configuration
        print $out "    backend:\n";
        print $out "      addresses:\n";
        foreach my $addr (@{$lb->{backend}->{addresses}}) {
          print $out "        - $addr\n";
        }

        # Write TLS configuration if present
        if ($lb->{tls}) {
          print $out "    tls:\n";
          print $out "      certificates: ~\n";
        }

        # Write ACLs if present
        if ($lb->{acls} && @{$lb->{acls}}) {
          print $out "    acls:\n";
          foreach my $acl (@{$lb->{acls}}) {
            print $out "    - name: $acl->{name}\n";

            if ($acl->{allow} && @{$acl->{allow}}) {
              print $out "      allow:\n";
              foreach my $allow (@{$acl->{allow}}) {
                print $out "        - $allow\n";
              }
            }

            if ($acl->{deny} && @{$acl->{deny}}) {
              print $out "      deny:\n";
              foreach my $deny (@{$acl->{deny}}) {
                print $out "        - $deny\n";
              }
            }
          }
        }
      }

      $written_lb = 1;
    } elsif ($in_lb_section && $line =~ /^\s*[a-zA-Z]/) {
      $in_lb_section = 0;
      print $out $line;
    } elsif ($in_lb_section && !$written_lb) {
      # Skip existing load balancer config
    } else {
      print $out $line;
    }
  }
  close $out;
}

1;

