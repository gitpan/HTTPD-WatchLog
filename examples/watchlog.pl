#!/usr/bin/perl --

use strict;
use HTTPD::WatchLog;

my $log = new HTTPD::WatchLog;

$log->file( $ARGV[0] ) if -r $ARGV[0];

# turn on DNS lookup
$log->addr2host(1);

# check error request
$log->highlight( ' 404 ', ' 500 ' );

# check head and post method
$log->highlight( 'HEAD ', 'POST ' );

# ignore local access
$log->ignore( 'localhost', 'intra' );
$log->ignore( '192\.168\.', '10\.0\.0\.' );

# define trigger.
my $sub = sub {
  my $line = shift;
  print "\033[1m*** worm detected ! \033[0m\n" if $line =~ m|/root\.exe|
    or $line =~ m|/cmd\.exe|;
};

sub foo {
  exit(0) if shift =~ /google/;
}

$log->trigger( $sub, \&foo );

# go!
$log->watch;
