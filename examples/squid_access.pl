#!/usr/bin/perl --

use strict;
use HTTPD::WatchLog 0.02;
$| = 1;

my $log = new HTTPD::WatchLog;

my $file = '/usr/local/squid/logs/access.log';
$file = $ARGV[0] if $ARGV[0] and -r $ARGV[0];
$log->file( $file );

# turn on DNS lookup
#$log->addr2host(1);

# pattern quote on
$log->quote(1);

# cached req
$log->highlight( ' TCP_HIT/200 ', ' TCP_REFRESH_HIT/200 ', ' TCP_MEM_HIT/200 ' );
$log->highlight( ' TCP_REFRESH_HIT/304', ' TCP_IMS_HIT/304' );

# mpg trap
my $sub = sub {
  my $line = shift;
  print "\033[1m*** humm.. is this a big one? \033[0m\n"
    if $line =~ m|\.mpg|;
};

my $sub2 = sub {
  my $line = shift;
  $line =~ s@^[\d\.]{1,}\s|\t@@;
};

$log->trigger( $sub, $sub2 );

# go!
$log->watch;

