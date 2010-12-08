#!/usr/bin/perl

use feature 'say';
use DBI;
use Data::Dumper;

$dbh = DBI->connect("dbi:Pg:dbname=maps", '', '', {AutoCommit => 0, RaiseError => 1});

my $rows  = $dbh->selectall_arrayref('SELECT groupname, descriptio, ASKML(the_geom) FROM onstreet');

say '<?xml version="1.0" encoding="UTF-8"?>';
say '<kml xmlns="http://www.opengis.net/kml/2.2">';
say '<Document><name>Dallas Bike Plan Routes</name>';
foreach my $row (@$rows) {
				my ($group, $desc, $line) = @$row;
				next unless ($group eq 'Greater Dallas Bike Plan');

				say "<Placemark><name>$desc</name>";
				say $line;
				say '</Placemark>';
}
say '</Document></kml>';
