#!/usr/bin/perl --

use strict;
use HTTPD::WatchLog 0.03;
$| = 1;

my $log = new HTTPD::WatchLog;
$log->file( $ARGV[0] ) if $ARGV[0] && -r $ARGV[0];

# turn on DNS lookup
$log->addr2host(1);

# pattern quote on
$log->quote(1);

# pack multibyte chars on
$log->pack(1);

# set width
$log->align_width or $log->width(80);

# check error request
$log->highlight( ' 404 ', ' 500 ' );

# check head and post method
$log->highlight( 'HEAD ', 'POST ' );

# ignore local access
$log->ignore( 'localhost', 'intra' );
$log->ignore( '192.168.', '10.0.0.' );

# i dont wanna see img and script access..
$log->ignore( '.jpg ', '.gif ', '.png ' );
$log->ignore( '.css ', '.js ' );

# define trigger.
$log->trigger( sub {
  my $line = shift;
  print "\033[1m*** worm detected ! \033[0m\n"
    if $line =~ m|/root\.exe| or $line =~ m|/cmd\.exe|;
} );

# go!
$log->watch;

