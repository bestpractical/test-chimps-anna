package Test::Chimps::Anna;

use warnings;
use strict;

use Carp;
use Jifty::DBI::Handle;
use Test::Chimps::Report;
use Test::Chimps::ReportCollection;
use YAML::Syck;

use base 'Bot::BasicBot';

=head1 NAME

Test::Chimps::Anna - The great new Test::Chimps::Anna!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Anna is a bot.

Anna is an IRC bot, specifically, which watches for new Test::Chimps smoke 
reports and talks to a specified channel when she sees one.

    use Test::Chimps::Anna;

    my $foo = Test::Chimps::Anna->new();
    ...

=cut

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  $self = bless $self, $class;
  my %args = @_;
  if (! exists $args{database_file}) {
    croak "You must specify SQLite database file!";
  }
  if (exists $args{config_file}) {
    my $columns = LoadFile($args{config_file});
    foreach my $var (@$columns) {
      package Test::Chimps::Report::Schema;
      column($var, type(is('text')));
    }
  }
  $self->{database_file} = $args{database_file};
  
  $self->{handle} = Jifty::DBI::Handle->new();
  $self->{handle}->connect(driver => 'SQLite', database => $self->{database_file})
    or die "Couldn't connect to database";

  $self->{oid} = $self->_get_highest_oid;
  $self->{first_run} = 1;
  return $self;
}

sub _get_highest_oid {
  my $self = shift;
  
  my $reports = Test::Chimps::ReportCollection->new(handle => $self->_handle);
  $reports->columns(qw/id/);
  $reports->unlimit;
  $reports->order_by(column => 'id', order => 'DES');
  $reports->rows_per_page(1);

  my $report = $reports->next;
  return $report->id;
}

sub _handle {
  my $self = shift;
  return $self->{handle};
}

sub _oid {
  my $self = shift;
  return $self->{oid};
}

sub tick {
  my $self = shift;

  if ($self->{first_run}) {
    $self->_say_to_all("I'm going to ban so hard");
    $self->{first_run} = 0;
  }

  my $reports = Test::Chimps::ReportCollection->new(handle => $self->_handle);
  $reports->limit(column => 'id', operator => '>', value => $self->_oid);
  $reports->order_by(column => 'id');

  while(my $report = $reports->next) {
    if ($report->total_failed || $report->total_unexpectedly_succeeded) {
      my $msg =
        "Smoke report for " .  $report->project . " r" . $report->revision . " submitted: "
        . sprintf( "%.2f", $report->total_ratio * 100 ) . "\%, "
        . $report->total_seen . " total, "
        . $report->total_ok . " ok, "
        . $report->total_failed . " failed, "
        . $report->total_todo . " todo, "
        . $report->total_skipped . " skipped, "
        . $report->total_unexpectedly_succeeded . " unexpectedly succeeded.  "
        . $self->{server_script} . "?id=" . $report->id;

      $self->_say_to_all($msg);
    }
  }

  my $last = $reports->last;
  if (defined $last) {
    # we might already be at the highest oid
    $self->{oid} = $last->id;
  }
  
  return 5;
}
  
sub _say_to_all {
  my $self = shift;
  my $msg = shift;

  $self->say(channel => $_, body => $msg)
    for (@{$self->{channels}});
}

=head1 AUTHOR

Zev Benjamin, C<< <zev at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-chimps-anna at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Chimps-Anna>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Chimps::Anna

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Chimps-Anna>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Chimps-Anna>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Chimps-Anna>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Chimps-Anna>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Zev Benjamin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Test::Chimps::Anna
