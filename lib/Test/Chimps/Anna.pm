package Test::Chimps::Anna;

use warnings;
use strict;

use Carp;
use IO::Dir;
use File::Spec;
use YAML::Syck;
use Test::Chimps::Report;

use base 'Bot::BasicBot';

=head1 NAME

Test::Chimps::Anna - The great new Test::Chimps::Anna!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Test::Chimps::Anna;

    my $foo = Test::Chimps::Anna->new();
    ...

=cut

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  my %args = @_;
  if (! exists $args{report_dir}) {
    croak "You must specify a report directory!";
  }
  $self->{report_dir} = $args{report_dir};
  $self->{files_seen} = {};
  $self->{first_run} = 1;
  $self = bless $self, $class;
  $self->_scan_reports;
  return $self;
}

sub report_dir {
  my $self = shift;
  return $self->{report_dir};
}

sub _files_seen {
  my $self = shift;
  return $self->{files_seen};
}

sub tick {
  my $self = shift;

  if ($self->{first_run}) {
    $self->_say_to_all("I'm going to ban so hard");
    $self->{first_run} = 0;
  }
  
  my @reports = $self->_scan_reports;

  foreach my $reportfile (@reports) {
    my $report = LoadFile($reportfile);
    my $vars = $report->report_variables;
    my $model = Test::TAP::Model::Visual->new_with_struct($report->model_structure);
    if ($model->total_failed || $model->total_unexpectedly_succeeded) {
      $reportfile =~ m{/([a-f0-9]+)\.yml$};
      my $id = $1;
      my $msg =
        "Smoke report for $vars->{project} r$vars->{revision} submitted: "
        . sprintf( "%.2f", $model->total_ratio * 100 ) . "\%, "
        . $model->total_seen . " total, "
        . $model->total_ok . " ok, "
        . $model->total_failed . " failed, "
        . $model->total_todo . " todo, "
        . $model->total_skipped . " skipped, "
        . $model->total_unexpectedly_succeeded . " unexpectedly succeeded.  "
        . $self->{server_script} . "?id=$id";

      $self->_say_to_all($msg);
    }
  }
  
  return 5;
}
  
sub _say_to_all {
  my $self = shift;
  my $msg = shift;

  $self->say(channel => $_, body => $msg)
    for (@{$self->{channels}});
}

sub _scan_reports {
  my $self = shift;

  my $dir = $self->{report_dir};
  my %new = ();
  
  my $d = IO::Dir->new($dir)
    or die "Could not open report directory: $dir: $!";
  while (defined(my $entry = $d->read)) {
    if (! exists $self->_files_seen->{$entry}) {
      $new{File::Spec->catfile($dir, $entry)}++;
      $self->{files_seen}->{$entry}++;
    }
  }
  return keys %new;
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
