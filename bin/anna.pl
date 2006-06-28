#!/usr/bin/env perl

use Test::Chimps::Anna;

my $anna = Test::Chimps::Anna->new(
  server   => "irc.perl.org",
  port     => "6667",
  channels => ["#bps"],

  nick      => "anna",
  username  => "nice_girl",
  name      => "Anna",
  report_dir => '/var/www/bps-smokes/reports',
  server_script => 'http://smoke.bestpractical.com/cgi-bin/report_server.pl'
  );

$anna->run;
