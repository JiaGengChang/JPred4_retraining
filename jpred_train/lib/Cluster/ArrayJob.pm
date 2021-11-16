package Cluster::ArrayJob;

our $VERSION = '0.3';

=head1 NAME

CLuster::ArrayJob - module/class to manage cluster jobs

=head1 SYNOPSIS



=head1 DESCRIPTION



=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2008, Chris Cole. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

use strict;
use warnings;
use Cluster::Job;

## inherit from the Job class
our @ISA = qw(Cluster::Job);

my $sgeSource = '/gridware/sge/default/common/settings.sh';

sub new {
  my ( $class, %args ) = @_;
  my $self = $class->SUPER::new();
  bless( $self, $class );

  # Automatically run any arguments passed to the constructor
  foreach my $k ( keys %args ) {
    warn "ERROR - No such method '$k' of object $class\nDied" unless $self->can($k);
    $self->$k( $args{$k} );
  }

  return ($self);
}

sub taskRange {
  my $self  = shift;
  my $range = shift;

  if ( $range =~ /\d+-\d+/ ) {
    $self->{range} = $range;
  } else {
    $self->error("array task range '$range' not in valid format");
  }
  return (1);
}

sub submit {
  my $self = shift;
  my $cmd  = shift;

  if ( !$cmd ) {
    $self->error('No command given for submission');
    return (0);
  }

  ## check there are no outstanding errors
  return (0) if ( $self->error() );

  my $submitString = "source $sgeSource && qsub";
  if ( defined( $self->{range} ) ) {
    $submitString .= " -t $self->{range}";
  } else {
    $self->error('No task range given for array job.');
    return (0);
  }

  if ( defined( $self->{env} ) ) {
    foreach my $env ( keys %{ $self->{env} } ) {
      my $value = $self->{env}{$env};
      $submitString .= " -v $env=$value";
    }
  }

  if ( defined( $self->{peSlots} ) ) {
    $submitString .= " -pe smp $self->{peSlots}";
  }

  if ( defined( $self->{project} ) ) {
    $submitString .= " -P $self->{project}";
  }

  if ( defined( $self->{resources} ) ) {
    foreach my $res ( keys %{ $self->{resources} } ) {
      $submitString .= " -l $res=$self->{resources}{$res}";
    }
  }

  if ( defined( $self->{jobname} ) ) {
    $submitString .= " -N $self->{jobname}";
  }

  if ( defined( $self->{queue} ) ) {
    $submitString .= " -q $self->{queue}";
  }

  if ( defined( $self->{cwd} ) && $self->{cwd} ) {
    $submitString .= " -cwd";
  }

  if ( defined( $self->{notify} ) ) {
    $submitString .= " -M $self->{notify}{email} -m $self->{notify}{when}";
  }

  if ( defined( $self->{reserve} ) && $self->{binary} ) {
    $submitString .= " -R y";
  }

  if ( defined( $self->{binary} ) && $self->{binary} ) {
    $submitString .= " -b y";
  }

  if ( defined( $self->{jobshare} ) ) {
    $submitString .= " -js $self->{jobshare}";
  }

  if ( defined( $self->{priority} ) ) {
    $submitString .= " -p $self->{priority}";
  }

  $submitString .= " $cmd";
  print "CMD: $submitString\n";

  #return(1);

  my $qsubOut = `$submitString` or $self->error("Failed to submit job '$submitString' to the cluster. qsub status $?: $!");
  return (0) if ( $self->{error} );

  if ( $qsubOut =~ /^Your job-array (\d+).$self->{range}:1 \(.*\) has been submitted$/ ) {
    $self->jobid($1);
    return (1);
  } else {
    $self->error("unexpected output from qsub: $qsubOut");
    return (0);
  }
  return (1);
}

## different getStatus to parent as needs to be able to cope
## with multiple jobs running concurrently.
sub getStatus {
  my $self = shift;
  my $type = shift;

  $type = '' unless ($type);    # avoid uninitialised value warnings

  $self->error('No job has been submitted.') unless ( $self->{jobid} );
  $self->setUser() unless ( $self->{user} );
  return (0) if $self->error();
  $self->{status} = '';         # clear status setting if previously set

  my $cmd;
  if ( $type eq 'running' ) {
    $cmd = "source $sgeSource && qstat -u $self->{user} -s r | tail -n +3";
  } elsif ( $type eq 'queuing' ) {
    $cmd = "source $sgeSource && qstat -u $self->{user} -s p | tail -n +3";
  } else {
    $cmd = "source $sgeSource && qstat -u $self->{user} -s a | tail -n +3";
  }

  #my $qstatOut = `$cmd` or $self->{error} = "qstat failed with status $?: $!";
  open( my $QSTAT, '-|', "source $sgeSource && $cmd" ) or $self->error("qstat failed with status $?: $!");
  return (0) if ( $self->{error} );

  my %status;
  while (<$QSTAT>) {
    my ( $id, $priority, $name, $user, $state, $startDate, $startTime, $queue, $slots, $tasks ) = split;
    if ( defined( $self->{jobid} ) ) {
      if ( $id == $self->{jobid} ) {
        $status{$state}++;
      }
    } elsif ( defined( $self->{jobname} ) ) {
      if ( $name eq $self->{jobname} ) {
        $status{$state}++;
      }
    } else {
      error('Unable to check status of job with no id or name!');
      return (0);
    }
  }
  if ( scalar keys %status ) {
    return ( \%status );
  }

  ## if we're here it means the job wasn't found - not necessarily an error
  return (-1);

}

1;
