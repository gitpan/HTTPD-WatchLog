#!/usr/bin/perl --

use strict;
use HTTPD::WatchLog 0.03;
use FileHandle;
use File::Basename;
$| = 1;

my $log = new HTTPD::WatchLog;
$log->file( $ARGV[0] ) if $ARGV[0] and -r $ARGV[0];

my $logfile = sprintf "/tmp/%s_%s.log", 'HTTPD::WatchLog', File::Basename::basename($0);

my $fh = new FileHandle $logfile, 'w'
  or die qq/cannot open '$logfile'./;

# set filehandle
$log->fh($fh);

# turn on DNS lookup
$log->addr2host(1);

# pattern quote on
$log->quote(1);

# pack multibyte chars on
$log->pack(1);

# ignore local access
$log->ignore( 'localhost', 'intra' );
$log->ignore( '192.168.', '10.0.0.' );

# i dont wanna see img and script access..
$log->ignore( '.jpg ', '.gif ', '.png ' );
$log->ignore( '.css ', '.js ' );

$log->watch;

