package HTTPD::WatchLog;

use strict;
require 5.00502;    # for Class::Accessor 0.17 and qr// operator
use vars qw( $VERSION );
use base qw( Class::Accessor::Fast );
use Socket qw( inet_aton AF_INET );
use File::Tail;

$VERSION = '0.04';

sub new {
  my $param = shift;
  my $class = ref $param || $param;

  my %args = (
    file => '/usr/local/apache/logs/access_log',
    addr2host => 0,
    decor => 'bold',    # internal only
    quote => 0,
    pack => 0,
    width => undef,
    epoch2date => 0,
    fh => \*STDOUT,
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

  if( scalar( my @pattern = @_ ) ){
    for my $pattern(@pattern){
      $pattern = quotemeta $pattern if $self->quote;
      $self->{ignore}->{qr/$pattern/} = 1;
    }
  }

  return scalar keys %{ $self->{ignore} };
}

sub highlight {
  my $self = shift;

  if( scalar( my @pattern = @_ ) ){
    for my $pattern(@pattern){
      $pattern = quotemeta $pattern if $self->quote;
      $self->{highlight}->{qr/$pattern/} = 1;
    }
  }

  return scalar keys %{ $self->{highlight} };
}

sub trigger {
  my $self = shift;

  if( scalar( my @code = @_ ) ){
    for my $code(@code){
      next if ref $code ne 'CODE';
      push @{$self->{trigger}}, $code;
    }
  }

  return scalar @{ $self->{trigger} };
}

sub align_width {
  my $self = shift;

  eval "use Term::Size;";
  return if $@;

  my($columns, $rows) = Term::Size::chars( *STDOUT{IO} );
  $self->width( $columns ) if $columns =~ /^\d+$/ && $columns > 0;

  return $self;
}

sub watch {
  my $self = shift;
  $self->file(shift) if @_;

  if( not -r $self->file ){
    warn sprintf qq/%s: cannot read '%s'./, __PACKAGE__, $self->file;
    return;
  }

  my $file = File::Tail->new(
    name => $self->file,
    interval => 1.0,
    adjustafter => 1.0,
  ) or do {
      warn sprintf qq/%s: cannot construct File::Tail object./, __PACKAGE__;
      return;
    };

  LOOP:

  while( defined( my $line = $file->read ) ){  

    # addr2host
    $line =~ s/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/eval{ (gethostbyaddr(inet_aton($1), AF_INET))[0] } || $1 /geo
	if $self->addr2host;

    # epoch2date
    $line =~ s/(\d{9,10}\.\d{1,5})/ sprintf "%s %s", (split m|\s+|, scalar localtime $1)[2,3] /geo
	if $self->epoch2date;

    # ignore
    for my $ignore( keys %{$self->{ignore}} ){
      if( $line =~ $ignore ){
	goto LOOP;
      }
    }

    # highlight
    for my $highlight( keys %{$self->{highlight}} ){
      $line =~ s/($highlight)/ sprintf "%s%s\033[0m", $self->_decor_str, $1 /ge;
    }

    # sub
    for( @{$self->{trigger}} ){
        my $rc = $_->($line);
    }

    # pack
    if( $self->pack ){
      $line =~ s/%([\da-fA-F][\da-fA-F])/ pack "C", hex $1 /geo;
    }

    # width
    if( $self->width =~ /^\d+/ and $self->width > 10 ){
	$line = substr $line, 0, $self->width;
	$line .= "\n" if $line !~ /\n$/;
    }

    my $fh = $self->fh || \*STDOUT;
    print $fh $line;
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

  return $decor->{$self->{decor}};
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

  # set some options
  $log->quote(1);
  $log->ignore('localhost', '192.168.0.');
  $log->ignore('/cgi-bin/');
  $log->highlight('POST ');
  $log->highlight(' 404 ', ' 500 ');

  $log->pack(1);
  $log->align_width or $log->width(120);
  $log->epoch2date(1);
  $log->fd($fh);

  # regist triggers
  $log->trigger( sub {
      my $line = shift;
      print STDERR "*** worm detected! \n" if $line =~ m|/root\.exe|;
    } );

  # go!
  $log->watch;

=head1 DESCRIPTION

HTTPD::WatchLog is designed for watching Apache webserver's (or Squid's) AccessLog in realtime.
This module provides unix command tail(1) like environment with more enhancement.

At least on FreeBSD, this doesn't work properly,

  shell> tail -F access_log | grep -v foo | grep -v bar | grep -v buz ...

so I need other facile solutions.

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

	the same as below. You can set it when you don't want to put regex
	into 'ignore' or 'highlight' list.

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
	my $sub2 = sub {  ...  };
	$log->trigger( $sub, $sub2 );

B<pack()>

	Pack MIME-encoded multibyte charactors to plain text. boolean value.

	$log->pack(1);    # on
	$log->pack(0);    # off (default)

B<width()>

	Truncate the tail of each lines. The chars after 'width' butes will
	be deleted. This means you don't need to see folded lines.

	$log->width(80);    # showed only 80 chars from line head.
	$log->width(0);    # off (default)

B<align_width()>

	Autoset the terminal columns to width by using Term::Size.

	$log->align_width;
	$log->align_width or $log->width(120);

B<epoch2date()>

	Replace epoch-like digits to human-readable string. boolean value.
	This may be useful in squid log.

	e.g. 1068056885.612 -> 6 03:28:05

	$log->epoch2date(1);    # on
	$log->epoch2date(0);    # off (default)

B<fh()>

	Set filehandle object. 'STDOUT' is default.

	my $fh = new FileHandle $logfile, 'w';
	$log->fh($fh);

B<watch()>

	Now you can get it ! That's all.

	$log->watch;

=head1 DEPENDENCY

File::Tail, Class::Accessor

=head1 AUTHOR

ryochin <ryochin@cpan.org>

=head1 SEE ALSO

perl(1), tail(1), File::Tail, Socket, Class::Accessor, Term::Size

=cut
