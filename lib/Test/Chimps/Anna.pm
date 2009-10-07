package Test::Chimps::Anna;

use warnings;
use strict;

use Carp;
use DateTime;
use Params::Validate qw(:all);
use Jifty::DBI::Handle;
use Test::Chimps::Report;
use Test::Chimps::ReportCollection;
use YAML::Syck;

use base 'Bot::BasicBot';

=head1 NAME

Test::Chimps::Anna - An IRC bot that announces test failures (and unexpected passes)

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';

=head1 SYNOPSIS

Anna is a bot.  Specifically, she is an implementation of
L<Bot::BasicBot>.  She will query your smoke report database and
print smoke report summaries when tests fail or unexpectedly
succeed.

    use Test::Chimps::Anna;

    my $anna = Test::Chimps::Anna->new(
      server   => "irc.perl.org",
      port     => "6667",
      channels => ["#example"],

      nick      => "anna",
      username  => "nice_girl",
      name      => "Anna",
      database_file => '/path/to/chimps/chimpsdb/database',
      config_file => '/path/to/chimps/anna-config.yml',
      server_script => 'http://example.com/cgi-bin/chimps-server.pl'
      );

    $anna->run;

=head1 METHODS

=head2 new ARGS

ARGS is a hash who's keys are mostly passed through to
L<Bot::BasicBot>.  Keys which are recognized beyond the ones from
C<Bot::BasicBot> are as follows:

=over 4

=item * database_file

Mandatory.  The SQLite database Anna should connect to get smoke
report data.

=item * server_script

Mandatory.  The URL of the server script.  This is used to display
URLs to the full smoke report.

=item * config_file

If your server accepts report variables, you must specify a config
file.  The config file is a YAML dump of an array containing the
names of those variables.  Yes, this is a hack.

=item * notices

If you want Anna to use /NOTICE instead of /SAY when sending updates,
provide a true value for this; defaults to false.

=back

=cut

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self = bless $self, $class;
    my %args = @_;
    if ( exists $args{config_file} ) {
        my $columns = LoadFile( $args{config_file} );
        foreach my $var (@$columns) {
            my $column = Test::Chimps::Report->add_column($var);
            $column->type("text");
            $column->writable(1);
            $column->readable(1);
            Test::Chimps::Report->_init_methods_for_column($column);
        }
    }
    $self->{notices} = $args{notices};

    $self->{handle} = Jifty::DBI::Handle->new();
    $self->{handle}->connect(
        driver   => $args{database_driver}   || "Pg",
        database => $args{database}          || "smoke",
        user     => $args{database_user}     || "postgres",
        password => $args{database_password} || ""
    );

    $self->{oid}              = $ENV{LATEST} || $self->_get_highest_oid;
    $self->{first_run}        = 1;
    $self->{passing_projects} = {};
    return $self;
}

sub _get_highest_oid {
    my $self = shift;

    my $reports = Test::Chimps::ReportCollection->new( handle => $self->_handle );
    $reports->columns(qw/id/);
    $reports->unlimit;
    $reports->order_by( column => 'id', order => 'DESC' );
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

=head2 tick

Overrided method.  Checks for new smoke reports every 2 minutes and
prints summaries if there were failed tests or if tests
unexpectedly succeeded.

=cut

sub tick {
    my $self = shift;

    if ( $self->{first_run} ) {
        $self->_say_to_all("I'm going to ban so hard");
        $self->{first_run} = 0;
    }

    my $reports = Test::Chimps::ReportCollection->new( handle => $self->_handle );
    $reports->limit( column => 'id', operator => '>', value => $self->_oid );
    $reports->order_by( column => 'id' );

    while ( my $report = $reports->next ) {
        if ( $report->total_failed || $report->total_unexpectedly_succeeded ) {
            $self->{passing_projects}->{ $report->project } = 0;

            my ( $rev, $committer, $date ) = $self->preprocess_report_metadata($report);

            my $msg
                = $report->project . " " 
                . $rev . " by "
                . $committer
                . $date . ": "
                . sprintf( "%.2f", $report->total_ratio * 100 ) . "\%, "
                . $report->total_seen
                . " total, "
                . $report->total_passed . " ok, "
                . $report->total_failed
                . " fail, "
                . $report->total_todo
                . " todo, "
                . $report->total_skipped
                . " skipped, "
                . $report->total_unexpectedly_succeeded
                . " unexpectedly ok; "
                . $report->duration . "s.  "
                . $self->{server_script} . "?id="
                . $report->id;

            $self->_say_to_all($msg);
        } else {
            if ( !exists $self->{passing_projects}->{ $report->project } ) {

                # don't announce if we've never seen this project before
                $self->{passing_projects}->{ $report->project } = 1;
            }
            if ( $self->{passing_projects}->{ $report->project }++ ) {
                my @exclam = ( qw/Yatta Woo Whee Yay Yippee Yow/, "Happy happy joy joy", "O frabjous day" );

                my ( $rev, $committer, $date ) = $self->preprocess_report_metadata($report);
                if ( $self->{passing_projects}->{ $report->project } % 5 == 0 ) {
                    $self->_say_to_all(
                              $report->project . " rev " 
                            . $rev
                            . (
                            $date
                            ? ( '(' . $date . ')' )
                            : ''
                            )
                            . " still passing all "
                            . $report->total_passed
                            . " tests.  "
                            . $exclam[ rand @exclam ] . "!"
                    );
                }
            } else {
                my ( $rev, $committer, $date ) = $self->preprocess_report_metadata($report);
                $self->_say_to_all( $report->project . " rev " 
                        . $rev . " by "
                        . $committer
                        . ( $report->can('committed_date') ? ' ' . $date : '' ) . "; "
                        . $report->duration . "s.  " . "All "
                        . $report->total_passed
                        . " tests pass" );
            }
        }
    }

    my $last = $reports->last;
    if ( defined $last ) {

        # we might already be at the highest oid
        $self->{oid} = $last->id;
    }

    return 5;
}

sub _say_to_all {
    my $self = shift;
    my $msg  = shift;

    if ( $self->{notices} ) {
        $self->notice( $_, $msg ) for ( @{ $self->{channels} } );
    } else {
        $self->say( channel => $_, body => $msg ) for ( @{ $self->{channels} } );
    }
}

sub preprocess_report_metadata {
    my $self      = shift;
    my $report    = shift;
    my $rev       = substr( $report->revision, 0, 6 );
    my $committer = $report->committer;
    $committer =~ s/^(?:.*)<(.*)>(?:.*)/$1/g;
    my $date;
    if ( $report->can('committed_date') ) {
        my $dt = $self->string_to_datetime( $report->committed_date );
        if ($dt) {
            $date = $self->age_as_string( time() - $dt->epoch );
        }
    }
    return ( $rev, $committer, $date );
}

my %MONTHS = (
    jan => 1,
    feb => 2,
    mar => 3,
    apr => 4,
    may => 5,
    jun => 6,
    jul => 7,
    aug => 8,
    sep => 9,
    oct => 10,
    nov => 11,
    dec => 12
);

use vars qw($MINUTE $HOUR $DAY $WEEK $MONTH $YEAR);

$MINUTE = 60;
$HOUR   = 60 * $MINUTE;
$DAY    = 24 * $HOUR;
$WEEK   = 7 * $DAY;
$MONTH  = 30.4375 * $DAY;
$YEAR   = 365.25 * $DAY;

sub string_to_datetime {
    my $self = shift;
    my ($date) = validate_pos( @_, { type => SCALAR | UNDEF } );
    if ( $date =~ /^(\d{4})-(\d{2})-(\d{2})[T\s](\d{1,2}):(\d{2}):(\d{2})Z?$/ ) {
        my ( $year, $month, $day, $hour, $min, $sec ) = ( $1, $2, $3, $4, $5, $6 );
        my $dt = DateTime->new(
            year      => $year,
            month     => $month,
            day       => $day,
            hour      => $hour,
            minute    => $min,
            second    => $sec,
            time_zone => 'GMT'
        );
        return $dt;
    }
    if ( $date =~ m!^(\d{4})/(\d{2})/(\d{2}) (\d{2}):(\d{2}):(\d{2}) ([-+]?\d{4})?! ) {

        # e.g. 2009/03/21 10:03:05 -0700
        my ( $year, $month, $day, $hour, $min, $sec, $tz ) = ( $1, $2, $3, $4, $5, $6, $7 );
        my $dt = DateTime->new(
            year      => $year,
            month     => $month,
            day       => $day,
            hour      => $hour,
            minute    => $min,
            second    => $sec,
            time_zone => $tz || 'GMT'
        );
        $dt->set_time_zone('GMT');
        return $dt;
    }

    if ( $date =~ /^(\w{3}) (\w{3}) (\d+) (\d\d):(\d\d):(\d\d) (\d{4}) ([+-]?\d{4})$/ ) {
        my ( $wday, $mon, $day, $hour, $min, $sec, $year, $tz ) = ( $1, $2, $3, $4, $5, $6, $7, $8 );
        my $dt = DateTime->new(
            year      => $year,
            month     => $MONTHS{ lc($mon) },
            day       => $day,
            hour      => $hour,
            minute    => $min,
            second    => $sec,
            time_zone => $tz || 'GMT'
        );
        $dt->set_time_zone('GMT');
        return $dt;

    }

    if ($date) {
        require DateTime::Format::Natural;

        # XXX DO we want floating or GMT?
        my $parser = DateTime::Format::Natural->new( time_zone => 'floating' );
        my $dt = $parser->parse_datetime($date);
        if ( $parser->success ) {
            return $dt;
        }
    }

    return undef;
}

sub age_as_string {
    my $self     = shift;
    my $duration = int shift;

    my ( $s, $time_unit );

    if ( $duration < $MINUTE ) {
        $s         = $duration;
        $time_unit = "sec";
    } elsif ( $duration < ( 2 * $HOUR ) ) {
        $s         = int( $duration / $MINUTE + 0.5 );
        $time_unit = "min";
    } elsif ( $duration < ( 2 * $DAY ) ) {
        $s         = int( $duration / $HOUR + 0.5 );
        $time_unit = "hours";
    } elsif ( $duration < ( 2 * $WEEK ) ) {
        $s         = int( $duration / $DAY + 0.5 );
        $time_unit = "days";
    } elsif ( $duration < ( 2 * $MONTH ) ) {
        $s         = int( $duration / $WEEK + 0.5 );
        $time_unit = "weeks";
    } elsif ( $duration < $YEAR ) {
        $s         = int( $duration / $MONTH + 0.5 );
        $time_unit = "months";
    } else {
        $s         = int( $duration / $YEAR + 0.5 );
        $time_unit = "years";
    }

    return "$s $time_unit ago";
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

=item * Mailing list

Chimps has a mailman mailing list at
L<chimps@bestpractical.com>.  You can subscribe via the web
interface at
L<http://lists.bestpractical.com/cgi-bin/mailman/listinfo/chimps>.

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Chimps-Anna>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Chimps-Anna>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Chimps-Anna>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Chimps-Anna>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2006 Best Practical Solutions.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
