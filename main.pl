#!/usr/local/bin/perl
use strict;
use warnings;
use Data::Dumper;

use LWP::UserAgent;
use HTML::TreeBuilder::XPath;
use Encode;
use Encode::CN;
use Date::Calc qw/Today Date_to_Time/;

$|++;

my $today = $ARGV[0];

unless ( $today ) {
  my ( $y, $m, $d ) = Today;
  $m = sprintf( "%02d", $m);
  $d = sprintf( "%02d", $d);
  $today = "$y-$m-$d";
};

unless ( $today =~ /^\d{4}-\d{2}-\d{2}$/ ) {
  die "Parse 178448 data\nCreated by: MC Cheung\nError data format\nPlease used: YYYY-MM-DD\n\n";
}

my ( $year, $month, $day ) = split /-/, $today;

my $max_time = Date_to_Time($year,$month,$day, 15,00,00 );
my $min_time = $max_time - 60 * 60 * 24;

my $ua = LWP::UserAgent->new();
my $log_file = "$today.txt";
my $is_first = -e $log_file ? 0:1;
my $find_old = 0;

my $old_data;
unless ( $is_first ) {
  $old_data = load_olddata( $log_file );
}



foreach my $page ( 1..6844 ) {
  my $url = "http://www.178448.com/plugin.php?id=fjzt:fjzt&mode=1&page=$page";
  print "$url\n";
  my $res = $ua->get( $url );
  if ( $res->is_success ) {
    my $page = decode('gb2312', $res->content() );
    $page = encode('utf8', $page);
    $page =~ s/\r\n//g;
    $page = $1 if $page =~ m{<div class="datalist">(.*?)</div>};

    while ( $page =~ m{<tr>(.*?)</script>}mig) {
      my $row = $1;
      #$row = encode('gb2312', $row );

      my @cols;
      while ( $row =~ m{<td.*?>(.*?)</td>}mig ){
        my $c = $1;
        push @cols, $c;
      }

      my ($stock_id, $id)  = ($1, $2) if $row =~ m{getprice\('(\d+)',(\d+),};

      if ( $id && $stock_id ) {
        if ( $old_data->{ $id } ){
          $find_old++;
          next;
        }
        #print "Stock id: $stock_id\t$id\n";
        #print join(',', @cols[-1..6]), "\n";
  $cols[0] =~ s/<a.*?>//g;
  $cols[0] =~ s/<\/a>//g;

  my $row_time = get_row_time( $cols[5] );
#   print $cols[5],"\n";
#   print "Max time: $max_time\nMin time: $min_time\nRow time: $row_time\n\n";

  if ( $row_time <= $max_time && $row_time >= $min_time ){
          save_data( \@cols,$id, $stock_id, $log_file );
  } elsif ( $row_time < $min_time ) {
    die "Finished fetch data for: $today\n";
  }
      }
      undef @cols;
    }
  }

  #print "Find_old: $find_old\n";
  last if $find_old > 5;
  #sleep( int(rand( 10)));
}

sub get_row_time {
  my ( $date_time ) = @_;

  my ( $y, $m, $d, $H, $M ) = ( $1, $2, $3, $4, $5 ) if $date_time =~ m/(\d{4})-(\d{2})-(\d{2})\s+(\d{2})\:(\d{2})/;
  if ( $y && $m && $d ) {
    return Date_to_Time( $y, $m, $d, $H || 0, $M || 0, 0 );
  }
  die "Can't get row date\n";
}




sub load_olddata {
  my ( $log_file ) = @_;
  $log_file ||= 'result.txt';
  open my $fh, '<', $log_file  || die "Can't open result.txt file\n";

  my %ids;
  while ( <$fh> ){
    my @cols = split /,/;
    $ids{ $cols[-2] }++;
  }
  return \%ids;
}

sub save_data {
  my ( $data,$id, $stock_id, $log_file ) = @_;

  open my $fh, '>>', $log_file || die "Can't open result.txt file\n";
  print $fh join(', ', @$data[0..6], $id, $stock_id);
  print $fh "\n";
  close $fh;
}

