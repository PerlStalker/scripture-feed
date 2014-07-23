#!/usr/bin/perl
use warnings;
use strict;

use DBI;
use XML::FeedPP;
use Time::Local;

my $base_url = 'http://perlstalker.vuser.org/Scriptures/';
my $output_dir = '/usr/local/nginx/html/Scriptures';
my $db_file = '/usr/local/share/scriptures.db';
my $type = 'verse';
my $num_days = '365';
my $DEBUG = 0;

my %vol_ids = ('ot' => 1,
	       'nt' => 2,
	       'bom' => 3,
	       'dc' => 4,
	       'pgp' => 5);

#my $dbh = DBI->connect("dbi:SQLite2:dbname=$db_file", "", "")
my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "")
    or die DBI->errstr;

my $now = time();
my @now = localtime($now);
my $yday = $now[7];
my $yday_10 = 1;
if ($yday > 10) {
    $yday_10 = $yday - 10;
}

my %pub_date = ();
for my $day (0 .. 9) {
    my $then = $now - (86400 * $day);
    my @then = localtime($then);
    $pub_date{$yday-$day} = timelocal(0, 0, 0, @then[3,4,5]);
}

foreach my $volume (qw(nt ot bom dc pgp)) {
    my $feed = new XML::FeedPP::RDF;
    my $num_verses;

    if (! -d "$output_dir/$volume") {
	print STDERR "Making $output_dir/$volume\n" if $DEBUG;
	mkdir "$output_dir/$volume"
	    or die "Unable to make $output_dir/$volume: $!\n";
    }

    my $sth = $dbh->prepare(
	"select count(verse_id) as num_verses from scriptures where volume_id = ?"
	);
    $sth->execute($vol_ids{$volume});
    my $results;
    if (defined ($results = $sth->fetchrow_hashref)) {
	$num_verses = $results->{num_verses};
    }

#    my $sth = $dbh->prepare("select * from lds_scriptures_volumes where volume_id = ?");
    $sth = $dbh->prepare("select * from volumes where id = ?");
    $sth->execute($vol_ids{$volume});

    my %volume = ();
    if (defined ($results = $sth->fetchrow_hashref)) {
	%volume = %$results;
    }
    $sth->finish;

    ## Set the feed title
    #$feed->title("Daily Study: ". $volume{volume_title_long});
    $feed->title("Daily Study: ". $volume{volume_long_title});
    $feed->link($base_url);
    $feed->pubDate(time());

    if (! -d "$output_dir") { mkdir "$output_dir"; }

    my @days = ();
    if ($type eq 'chapter') {
	for my $day ($yday_10 .. $yday) {
	    push @days, get_verses_for_chapters($dbh,
						$volume{id},
						$day,
						$num_verses,
						$num_days);
	}
    } elsif ($type eq 'verse') {
	for my $day ($yday_10 .. $yday) {
	    my $verses = get_verses_for_verses($dbh,
					       $volume{id},
					       $day,
					       $num_verses,
					       $num_days);
	    #my $item = $feed->add_item($base_url."rss.phtml?volume=$volume&day=$day");

	    my $item = $feed->add_item($base_url."$volume/verses_$day.html");
	    my $title = $volume{volume_long_title}.": day $day";
	    $item->title($title);
	    $item->pubDate($pub_date{$day});
	    if (@$verses) {
		my $html = '';
		for my $i (0 .. @$verses - 1) {
		    my $verse = $verses->[$i];

		    $html .= '<p>';
		    if ($i == 0) {
			$html .= $verse->{verse_short_title};
		    }
		    else {
			if ($verse->{verse_number} == 1) {
			    $html .= '<b>'.$verse->{verse_title}.'</b>';
			}
			else {
			    $html .= $verse->{verse_number};
			}
		    }
		    $html .= ' ';
		    $html .= $verse->{scripture_text};
		    $html .= '</p>';
		}
		$item->description($html);

		write_html("$output_dir/$volume/verses_$day.html", $title, $html);
	    } else {
		$item->description('<p>You have finished!</p>');
		write_html("$output_dir/$volume/verses_$day.html", $title,
		    "<p>You have finished!</p>");
	    }
	}
    }

    $feed->to_file($output_dir."/$volume.rdf");
}

sub write_html {
    my $file  = shift;
    my $title = shift || 'Daily Scripture Study';
    my $html  = shift;

    open (OUT, '>', $file)
	or die "Unable to write to $file: $!\n";
    print OUT "<html><head><title>$title</title></head><body>$html</body></html>";
    close OUT;
}

sub get_verses_for_chapters {
    my $day = shift;
    my $num_verses = shift;
    my $num_days = shift;

    my $verses = [];

    return $verses;
}

sub get_verses_for_verses {
    my $dbh = shift;
    my $vol_id = shift;
    my $day = shift;
    my $num_verses = shift;
    my $num_days = shift;

    my $perday = int (($num_verses/$num_days)+1);

    my $verses = [];

    my $offset = ($day - 1) * $perday;

    print STDERR "Offset: $offset; perday: $perday\n" if $DEBUG;

    my $sth = $dbh->prepare ("select * from scriptures where volume_id = ? limit $offset, $perday")
	or die $dbh->errstr;
    $sth->execute($vol_id)
	or die $sth->errstr;
    #print STDERR ("SCR: $vol_id, $num_verses, $day, $perday, ", ($day - 1) * $perday,"\n");
    my $verse;
    while (defined ($verse = $sth->fetchrow_hashref)) {
	push @$verses, $verse;
    }

    return $verses;
}

