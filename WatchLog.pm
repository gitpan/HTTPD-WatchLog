package HTTPD::WatchLog;

=pod

=head1 NAME

HTTPD::WatchLog - watching Apache AccessLog in realtime

=head1 SYNOPSIS

  use HTTPD::WatchLog;

  # ready..
  my $log = new HTTPD::WatchLog;

  $log->file('/usr/local/apache/logs/combined_log');
  $log->addr2host(1);    # convert ip address to hostname

  # set options
  $log->ignore('localhost', '192\.168\.0\.');
  $log->ignore('/cgi-bin/');
  $log->highlight('POST ');
  $log->highlight(' 404 ', ' 500 ');

  # regist triggers
  my $sub = sub {
    my $line = shift;
    print STDERR "*** worm detected! \n" if $line =~ m|/root\.exe|;
  };
  sub foo {
    exit(0) if shift =~ /Macintosh/;
  }
  $log->trigger( $sub, \&foo );

  # go!
  $log->watch;

=head1 DESCRIPTION

HTTPD::WatchLog is designed for watching Apache webserver's AccessLog in realtime.
This module provides unix command tail(1) like environment with more enhancement.

=cut

use vars qw( $VERSION $Debug );
$VERSION = '0.01';

use strict;
use Socket qw( inet_aton AF_INET );
use File::Tail;
use base qw( Class::Accessor );

require 5.00502;    # for Class::Accessor 0.17 and qr//

sub new {
  my $class = shift;
  my %args = (
    file => '/usr/local/apache/logs/access_log',
    addr2host => 0,
    decor => 'bold',
    @_
  );

  # accessor
  __PACKAGE__->mk_accessors( keys %args );

  bless my $self = {
    ignore => {},
    highlight => {},
    trigger => [],
    %args,
  };  
}

=pod

=head1 METHOD

B<new()>

	Construct a object. Some values (provided as accessors) can be set here.

	my $log = HTTPD::WatchLog->new(
	    file => '/usr/local/apache/logs/access_log',
	    addr2host => 1,
	  );

B<file()>

	File path of what you want to watch. The default path is '/usr/local/apache/logs/access_log'.

	$log->file('/var/httpd/logs/combined_log');

B<addr2host()>

	Turn on ip address to hostnam DNS lookup switch. boolean value.

	$log->addr2host(1);    # on
	$log->addr2host(0);    # off (default)

=cut

sub ignore {
  my $self = shift;

  for(@_){
    $self->{ignore}->{qr/$_/} = 1;
  }

  return $self;
}

=pod

B<ignore()>

	Set regex as scalar or array. The module ignores lines that cotains the regex(es).

	$log->ignore( 'localhost', '192\.168\.0\.' );
	$log->ignore( 'Mon' );    # i hate monday of course .. ;-)

=cut

sub highlight {
  my $self = shift;

  for(@_){
    $self->{highlight}->{qr/$_/} = 1;
  }

  return $self;
}

=pod

B<highlight()>

	Set regex as scalar or array. highlight()ed term is highlightly showed if you use proper terminal.

	$log->highlight( 'HEAD ', 'POST ' );
	$log->highlight( 'root\.exe' );

=cut


sub trigger {
  my $self = shift;

  push @{$self->{trigger}}, @_;

  return $self;
}

=pod

B<trigger()>

	Regist trigger subroutines as scalar or array.

	my $sub = sub {  ...  };
	sub foo {  ...  };

	$log->trigger( $sub );
	$log->trigger( $sub, \&foo );

=cut

sub watch {
  my $self = shift;
  $self->file( shift ) if @_;

  die qq/cannot open '$self->{file}'./ if not -r $self->{file};

  my $file = File::Tail->new(
    name => $self->{file},
    interval => 1.0,
    adjustafter => 1.0,
  ) or die q/cannot construct File::Tail object./;


  my $decor = {
    bold => "\033[1m",
    underline => "\033[4m",
  };

  LOOP:

  while( defined( my $line = $file->read() ) ){  

    $line =~ s/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/eval{ (gethostbyaddr(inet_aton($1), AF_INET))[0] || $1 }/e
      if $self->{addr2host};

    # ignore
    for( keys %{$self->{ignore}} ){
      if( $line =~ $_ ){
	goto LOOP;
      }
    }

    # highlight
    for( keys %{$self->{highlight}} ){
      $line =~ s/($_)/sprintf "%s%s\033[0m", $decor->{$self->{decor}}, $1/ge;
    }

    # sub
    for( @{$self->{trigger}} ){
        $_->($line) if ref $_ eq 'CODE';
    }

    print $line;
  }

  return $self;
}

=pod

B<watch()>

	Now you can got it ! That's all.

	$log->watch;

=cut

sub view {
  shift->watch(@_)
}

return 1;

__END__

=pod

=head1 DEPENDENCY

File::Tail, Class::Accessor

=head1 AUTHOR

Okamoto RYO <ryo@aquahill.net>

=head1 SEE ALSO

perl(1), tail(1), File::Tail, Socket, Class::Accessor

=head1 TODO

Thinking now.. This module is experimental one, please tell me your ideas. :-)

=cut

