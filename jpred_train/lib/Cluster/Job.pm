package Cluster::Job;

our $VERSION = '0.4.1';

=head1 NAME

Cluster::Job - class to manage cluster jobs

=head1 SYNOPSIS

   my $job = Cluster::Job->new();  # create new instance of object
   $job->jobname('piecesof8');     # set job name
   $job->setCWD();                 # toggle the current working directory flag
   $job->setBinary();              # toggle the binary option
   $job->setProjectName('barton'); # specify the project name to run the job under
   $job->setParallel(4);           # use the parallel environment using 4 cores
   $job->submit('script.sh')       # run the 'script.sh' on the cluster
   $job->getStatus();              # retrieve the job's status
   $job->delete();                 # delete the job


=head1 DESCRIPTION

Use this module to prepare, submit and monitor jobs run via the Sun Grid Engine (SGE) job scheduler.

Currently, the most common options for qsub, qstat and qdel have been implemented. More advanced options for altering job settings (qalter) and resubmission of jobs (qresub) have not been implemented.

Briefly, the qsub options accessible by this class are (and the method to use):

   -q   queue()
   -P   setProjectName()
   -pe  setParallel()
   -l   setResourceRequest()
   -m/M setNotification()
   -cwd setCWD()
   -b   setBinary()
   -R   setReservation()
   -u   user()
   -N   jobname()
   -e   setErrorPath()
   -o   setStdoPath()
   
See the qsub manpage for details on the use these options. Here, only details of the implementation are discussed and a good working understanding of SGE is assumed.  

=head1 METHODS

Below are the details of using all the methods. Unless otherwise specified, the methods return true on success or false on failure. Failures set an error string, which can be checked using the error() method.

=cut

use strict;
use warnings;

my $sgeSource       = '/gridware/sge/default/common/settings.sh';
my %allowedQ        = qw(64bit-pri.q 1 64bit.q 1 ge-pri.q 1 bigmem.q 1 devel.q 1);
my %allowedResource = qw(qname 1 h_vmem 1 mem_used 1 mem_total 1 ram 1);
my %allowedProject  = qw(barton 1 webservices 1);

=over 5

=item B<new()>

Object constructor. Returns a Cluster::Job object.

=cut

sub new {
  my ( $class, %args ) = @_;
  my $self = {};
  bless( $self, $class );

  # Automatically run any arguments passed to the constructor
  foreach my $k ( keys %args ) {
    warn "ERROR - No such method '$k' of object $class\nDied" unless $self->can($k);
    $self->$k( $args{$k} );
  }

  return ($self);
}

=item B<jobname()>

Specify a name for the job. Takes a single string parameter. Can't be too long as SGE will concatenate it.

If no parameter given, will return the current value of the job name.

=cut

sub jobname {
  my $self = shift;
  my $name = shift;

  if ($name) {
    $self->{jobname} = $name;
  }
  if ( defined( $self->{jobname} ) ) {
    return ( $self->{jobname} );
  } else {

    # $self->error('No jobname set for current job');
    return (0);
  }
}

=item B<setProjectName()>

Specify the project name to use when running the job. Currently, only the 'barton' and 'webservices' projects are allowed.

=cut

sub setProjectName {
  my $self = shift;
  my $name = shift;

  if ( $allowedProject{$name} ) {
    $self->{project} = $name;
  } else {
    $self->error("Invalid project name: '$name'");
    return (0);
  }
}

=item B<setParallel()>

Use the parallel environment and set the number of slots to use.

Requires a positive integer number as a parameter. A maximum value is not checked for. Anything above '8' could result in odd behaviour. You have been warned!

=cut

sub setParallel {
  my $self     = shift;
  my $numSlots = shift;

  warn "Warning - memory limits already set. Parallel jobs may fail when memory limits are set.\n" if ( defined( $self->{resources}{'h_vmem'} ) );

  # check it's a number
  if ( $numSlots =~ /^\d+$/ ) {
    $self->{peSlots} = $numSlots;
  } else {
    $self->error("SetParallel() not supplied a valid number: '$numSlots'. Positive integer numbers only allowed.");
    return (0);
  }
}

=item B<setEnv()>

Set an environment variable. Can be used multiple times.

Requires an environment variable name and value.

=cut

sub setEnv() {
  my $self = shift;
  my (%args) = @_;

  if ( !scalar keys %args ) {
    $self->error("setEnv() not a given any environment variable parameters.");
    return (1);
  }

  foreach my $k ( keys %args ) {
    $self->error("Environment variable '$k' passed to setEnv() not given a value.") unless ( defined( $args{$k} ) );
    $self->{env}{$k} = $args{$k};
  }

}

=item B<setJobShare()>

Define the jobshare value for the job.

=cut

sub setJobShare {
  my $self  = shift;
  my $value = shift;

  if ( defined($value) ) {
    if ( $value < 0 ) {
      warn "Warning - jobshare value is <0 which is not valid. Setting to 0.";
      $value = 0;
    }
    $self->{jobshare} = $value;
  }
  return ( $self->{jobshare} );
}

=item B<setErrorPath()>

Define path for standard error files

=cut

sub setErrorPath {
  my $self  = shift;
  my $value = shift;

  if ( defined($value) ) {
    $self->{e} = $value;
  }
  return ( $self->{e} );
}

=item B<setStdoPath()>

Define path for standard output files

=cut

sub setStdoPath {
  my $self  = shift;
  my $value = shift;

  if ( defined($value) ) {
    $self->{o} = $value;
  }
  return ( $self->{o} );
}

=item B<setPriority()>

Define the priority for the job.

=cut

sub setPriority {
  my $self  = shift;
  my $value = shift;

  if ( defined($value) ) {
    $self->{priority} = $value;
  }
  return ( $self->{priority} );
}

=item B<setBinary()>/B<setReservation()>/B<setCWD()>

Set the binary/reservation/CWD SGE flags

By default the methods will switch on the flags. Can be over-ridden by giving 'T' (true) or 'F' (false) as a parameter.

=cut

sub setBinary {
  my $self = shift;
  my $flag = shift;

  $flag = 'T' unless ($flag);

  if ( $flag eq 'F' ) {
    $self->{binary} = 0;
  } elsif ( $flag eq 'T' ) {
    $self->{binary} = 1;
  } else {
    $self->error("Invalid option '$flag' for setBinary()");
    return (0);
  }
  return ();
}

sub setReservation {
  my $self = shift;
  my $flag = shift;

  $flag = 'T' unless ($flag);

  if ( $flag eq 'F' ) {
    $self->{reserve} = 0;
  } elsif ( $flag eq 'T' ) {
    $self->{reserve} = 1;
  } else {
    $self->error("Invalid option '$flag' for setReservation()");
    return (0);
  }
}

sub setCWD {
  my $self = shift;
  my $flag = shift;

  $flag = 'T' unless ($flag);

  if ( $flag eq 'F' ) {
    $self->{cwd} = 0;
  } elsif ( $flag eq 'T' ) {
    $self->{cwd} = 1;
  } else {
    $self->error("Invalid option '$flag' for setCWD()");
    return (0);
  }
}

=item B<setNotification()>

Specify an email address to notify changes to the status of the job and which changes to notify.

Requires a hash with the keys 'email' and 'when'. For valid 'when' options see the qsub manpage.

=cut

sub setNotification {
  my $self = shift;
  my (%args) = @_;

  foreach my $opt qw(email when) {
    unless ( $args{$opt} ) {
      $self->error("Required setNotification() parameter '$opt' is missing");
      return (0);
    }
    $self->{notify}{$opt} = $args{$opt};
  }
}

=item B<setResourceRequest()>

Specify key/value pairs for SGE resource requests.

So far, only 'qname', 'h_vmem' and 'mem_used' have been implemented. Anything else will raise an error.

Requires the pairs as a hash.

=cut

sub setResourceRequest {
  my $self = shift;
  my (%args) = @_;

  foreach my $resource ( keys %args ) {
    if ( $allowedResource{$resource} ) {
      ## check for h_vmem conflict with parallel jobs
      warn "Warning - setting memory limits for a parallel job may make it fail.\n" if ( $resource eq 'h_vmem' && defined( $self->{peSlots} ) );
      $self->{resources}{$resource} = $args{$resource};
    } else {
      warn "Warning - resource '$resource' not allowed/known. Skipping...\n";
    }
  }
}

=item B<getResourceRequest()>

Return specified resource requests as a hash.

=cut

sub getResourceRequest {
  my $self = shift;

  if ( defined( $self->{resources} ) ) {
    return ( $self->{resources} );
  } else {
    return (0);
  }
}

=item B<jobid()>

Define or retrieve the job id of the currently running job.

Job ids are defined by SGE upon submission of a job. Only use this method to set job ids with great care as problems could arise if you're not careful.   

=cut

sub jobid {
  my $self = shift;
  my $id   = shift;

  if ($id) {
    $self->{jobid} = $id;
  }
  if ( defined( $self->{jobid} ) ) {
    return ( $self->{jobid} );
  } else {
    $self->error('No jobid set for current job');
    return (0);
  }
}

=item B<setUser()>

Set the user name of the owner of the current job.

Requires a name to use otherwise sets to the current owner. This is probably only useful for checking status of other jobs.

=cut

sub setUser {
  my $self = shift;
  my $user = shift;

  if ($user) {
    $self->{user} = $user;
  } else {
    $self->{user} = $ENV{USER};
  }

  ## check user was set
  if ( defined( $self->{user} ) ) {
    return (1);
  } else {
    return (0);
  }
}

=item B<queue()>

Specify which queue to use.

Currently allowed queues are '64bit-pri.q', '64-bit.q' and 'devel.q'.

If no parameter used, return the current queue name. 

=cut

sub queue {
  my $self  = shift;
  my $qName = shift;

  if ($qName) {
    if ( defined( $allowedQ{$qName} ) ) {
      $self->{queue} = $qName;
      return ( $self->{queue} );
    } else {
      $self->error("queue 'qName' is not allowed");
      return (0);
    }
  } else {
    if ( defined( $self->{queue} ) ) {
      return ( $self->{queue} );
    } else {
      return (0);
    }
  }
}

=item B<submit()>

Submit command to the cluster queue.

Requires a command string to run. No checking is done of the command.

Checks that no errors are outstanding before submission and applies all user defined parameters. No defaults are assumed, apart from global defaults set in the SGE configs.

=cut

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
  if ( defined( $self->{resources} ) ) {
    foreach my $res ( keys %{ $self->{resources} } ) {
      $submitString .= " -l $res=$self->{resources}{$res}";
    }
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

  if ( defined( $self->{e} ) ) {
    $submitString .= " -e $self->{e}";
  }

  if ( defined( $self->{o} ) ) {
    $submitString .= " -o $self->{o}";
  }

  $submitString .= " $cmd";

  #print "CMD: $submitString\n";
  #return(1);

  my $qsubOut = `$submitString` or $self->error("Failed to submit job '$submitString' to the cluster. qsub status $?: $!");
  return (0) if ( $self->{error} );

  if ( $qsubOut =~ /^Your job (\d+) \(.*\) has been submitted$/ ) {
    $self->jobid($1);
    return ( $self->jobid($1) );
  } else {
    $self->error("unexpected output from qsub: $qsubOut");
    return (0);
  }
  return (1);
}

=item B<delete()>

Delete the job from the cluster whether it is running or not.

=cut

sub delete {
  my $self = shift;

  unless ( $self->{jobid} ) {
    $self->error('job has not been submitted and therefore cannot be deleted');
    return (0);
  }

  my $cmd = "source $sgeSource && qdel $self->{jobid}";
  my $qdelOut = `$cmd` or $self->error("Failed to delete job '$self->{jobid}'. Status $?: $!");
  if ( $qdelOut =~ /has registered the job $self->{jobid} for deletion/ ) {
    return (1);
  } else {
    $self->error("qdel failed: $qdelOut");
    return (0);
  }
}

=item B<getStatus>

Retrieve status information regarding a submitted job.

This method does nothing fancy and just returns the status flags as generated by qstat. It is up to the user to decide what to do with them. Frankly, there are probably too many combinations to be able to deal with them all automitcally in a sensible fashion.

=cut

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

  while (<$QSTAT>) {
    my ( $id, $priority, $name, $user, $state, $startDate, $startTime, $queue, $slots, $tasks ) = split;
    if ( defined( $self->{jobid} ) ) {
      if ( $id == $self->{jobid} ) {
        $self->{status} = $state;
        return ( $self->{status} );
      }
    } elsif ( defined( $self->{jobname} ) ) {
      if ( $name eq $self->{jobname} ) {
        $self->{status} = $state;
        return ( $self->{status} );
      }
    } else {
      error('Unable to check status of job with no id or name!');
      return (0);
    }
  }

  ## if we're here it means the job wasn't found - not necessarily an error
  return (-1);

}

=item B<error()>

Define/retrieve error state information.

Generally, error state information is set internally and retrieved by the user. 

=cut

sub error {
  my $self = shift;
  my $msg  = shift;

  if ($msg) {
    $self->{error} = $msg;
    return (1);
  }
  return ( $self->{error} );
}

1;

=head1 NOTES

There is a potential conflict when running (some) jobs in a parallel environment in conjunction with a hard memory limit request. The class deals with this situation by warning the user, but allows the job to continue as it's not certain that all types of job are affected. BLAST and hmmer are the prime suspects for problems, though.

=head1 AUTHOR

Chris Cole <christian@cole.name>

=head1 COPYRIGHT

Copyright 2008, Chris Cole. All rights reserved.

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
