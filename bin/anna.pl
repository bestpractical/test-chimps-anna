#!/usr/bin/env perl

use warnings;
use strict;

use Test::Chimps::Anna;

my $anna = Test::Chimps::Anna->new(
  server   => "irc.perl.org",
  port     => "6667",
  channels => ["#annatest"],

  nick      => "anna",
  username  => "nice_girl",
  name      => "Anna",
  database_file => '/home/chmrr/work/bps/Test-Chimps-Anna/database',
  config_file => '/home/chmrr/work/bps/Test-Chimps-Anna/anna-config.yml',
  server_script => 'http://smoke.bestpractical.com/cgi-bin/report_server.pl'
  );

$anna->run;
