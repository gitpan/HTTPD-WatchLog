package HTTPD::WatchLog;

use strict;
require 5.00502;    # for Class::Accessor 0.17 and qr// operator
use vars qw( $VERSION );
use base qw( Class::Accessor );
use Socket qw( inet_aton AF_INET );
use File::Tail;

$VERSION = '0.02';

sub new {
  my $param = shift;
  my $class = ref $param || $param;

  my %args = (
    file => '/usr/local/apache/logs/access_log',
    addr2host => 0,
    decor => 'bold',    # internal only
    quote => 0,
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

sub ignore {
  my $self = shift;
  my @pattern = @_;

  for my $pattern(@pattern){
    $pattern = quotemeta $pattern if $self->quote;
    $self->{ignore}->{qr/$pattern/} = 1;
  }

  return $self;
}

sub highlight {
  my $self = shift;
  my @pattern = @_;

  for my $pattern(@pattern){
    $pattern = quotemeta $pattern if $self->quote;
    $self->{highlight}->{qr/$pattern/} = 1;
  }

  return $self;
}

sub trigger {
  my $self = shift;

  for(@_){
    next if ref $_ ne 'CODE';
    push @{$self->{trigger}}, $_;
  }

  return $self;
}

sub watch {
  my $self = shift;
  $self->file(shift) if @_;

  die sprintf qq/cannot open '%s'./, $self->file if not -r $self->file;

  my $file = File::Tail->new(
    name => $self->file,
    interval => 1.0,
    adjustafter => 1.0,
  ) or die q/cannot construct File::Tail object./;

  LOOP:

  while( defined( my $line = $file->read() ) ){  

    # addr2host
    $line =~ s/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/eval{ (gethostbyaddr(inet_aton($1), AF_INET))[0] || $1 }/geo
	if $self->{addr2host};

    # ignore
    for my $ignore( keys %{$self->{ignore}} ){
      if( $line =~ $ignore ){
	goto LOOP;
      }
    }

    # highlight
    for my $highlight( keys %{$self->{highlight}} ){
#      $line =~ s/($highlight)/sprintf "%s%s\033[0m", $decor->{$self->{decor}}, $1/ge;
      $line =~ s/($highlight)/sprintf "%s%s\033[0m", $self->_decor_str, $1/ge;
    }

    # sub
    for( @{$self->{trigger}} ){
        my $res = $_->($line);
    }

    print STDOUT $line;
  }

  return $self;
}

sub view {
  shift->watch(@_)
}

sub _decor_str {
  my $self = shift;

  my $decor = {
    bold => "\033[1m",
    underline => "\033[4m",
  };

  return $decor->{$self->{decor}}
}

return 1;

__END__

=pod

=head1 NAME

HTTPD::WatchLog - watching Apache AccessLog simply in realtime

=head1 SYNOPSIS

  use HTTPD::WatchLog;

  # ready..
  my $log = new HTTPD::WatchLog;

  $log->file('/usr/local/apache/logs/combined_log');
  $log->addr2host(1);    # convert ip address to hostname

  # set options
  $log->quote(1);
  $log->ignore('localhost', '192.168.0.');
  $log->ignore('/cgi-bin/');
  $log->highlight('POST ');
  $log->highlight(' 404 ', ' 500 ');

  # regist triggers
  my $worm = sub {
    my $line = shift;
    print STDERR "*** worm detected! \n" if $line =~ m|/root\.exe|;
  };
  $log->trigger( $worm );

  # go!
  $log->watch;

=head1 DESCRIPTION

HTTPD::WatchLog is designed for watching Apache webserver's AccessLog in realtime.
This module provides unix command tail(1) like environment with more enhancement.

=head1 METHOD

B<new()>

	Construct a object. Some values (provided as accessors)
	can be set here.

	my $log = HTTPD::WatchLog->new(
	    file => '/usr/local/apache/logs/access_log',
	    addr2host => 1,
	  );

B<file()>

	File path of what you want to watch. The default path is
	'/usr/local/apache/logs/access_log'.

	$log->file('/var/httpd/logs/combined_log');

B<addr2host()>

	Turn on ip address to hostnam DNS lookup switch. boolean value.

	$log->addr2host(1);    # on
	$log->addr2host(0);    # off (default)

B<quote()>

	If true, meta characters in your regex patterns may be quoted
	using built-in quotemeta() function,

	$log->quote(1);   # on
	$log->quote(0);   # off (default)

	means these lines are ..

	$log->quote(0);
	$log->ignore('192\.168\.0\.');

	the same as below. you can set it when you don't want to put regex
	into ignore or hilight list.

	$log->quote(1);
	$log->ignore('192.168.0.');

B<ignore()>

	Set pattern(s) as scalar or array. The module ignores lines
	that cotains at least one of the pattern(s).

	$log->ignore( 'localhost', '192\.168\.0\.' );
	$log->ignore( 'Mon' );    # i hate monday of course .. ;-)

B<highlight()>

	Set pattern(s) as scalar or array. highlight()ed term is
	highlightly showed if you use proper terminal.

	$log->highlight( 'HEAD ', 'POST ' );
	$log->highlight( 'root\.exe' );

B<trigger()>

	Regist trigger subroutines as scalar or array.

	my $sub = sub {  ...  };
	sub foo {  ...  };

	$log->trigger( $sub );
	$log->trigger( $sub, \&foo );

B<watch()>

	Now you can got it ! That's all.

	$log->watch;

=head1 DEPENDENCY

File::Tail, Class::Accessor

=head1 AUTHOR

Okamoto RYO <ryo@aquahill.net>

=head1 SEE ALSO

perl(1), tail(1), File::Tail, Socket, Class::Accessor

=cut
