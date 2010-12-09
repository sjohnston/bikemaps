#!/usr/bin/perl

use strict;
use feature 'say';
use DBI;
use Data::Dumper;
use LWP::UserAgent;
use YAML qw(LoadFile);
use JSON::XS;

my $config = LoadFile('config.yaml');
my $osm_config = $config->{'OpenStreetMap'};

my $osm = osm(@{$osm_config}{qw(url user password)});

my $dbh = DBI->connect("dbi:Pg:dbname=maps", '', '', {AutoCommit => 0, RaiseError => 1});

my $rows = $dbh->selectall_arrayref(q{SELECT descriptio, ST_AsGeoJSON(the_geom) FROM onstreet WHERE groupname = 'Greater Dallas Bike Plan'});

my $new_changeset = '<osm><changeset><tag k="created_by" v="Perl"/><tag k="comment" v="Adding Dallas Cycle Routes"/></changeset></osm>';
my $change = $osm->(PUT => 'changeset/create', $new_changeset);

foreach my $row (@$rows) {
  my ($desc, $line_json) = @$row;
  my $line = decode_json $line_json;
  my $coords = shift @{$line->{'coordinates'}};

  create_route($osm, $desc, $coords);
}

$osm->(PUT => "changeset/$change/close");

sub create_route {
  my ($osm, $desc, $coords) = @_;

  my ($number) = $desc =~ /(\d+)$/;
  say "$desc:$number";

  my $way = qq{<osm><way changeset="$change"><tag k="lcn_ref" v="$number"/>};

  foreach my $c (@$coords) {
    my ($lon, $lat) = @$c;
    my $node = $osm->(PUT => 'node/create', qq{<osm><node changeset="$change" lat="$lat" lon="$lon"></node></osm>});
    $way .= qq{<nd ref="$node" />\n};
  }

  $way .= '</way></osm>';
  my $way = $osm->(PUT => 'way/create', $way);
  $osm->(PUT => 'relation/create', qq{<osm><relation changeset="$change">
  <member type="way" ref="$way"/>
  <tag k="type" v="route"/>
  <tag k="route" v="bicycle"/>
  <tag k="network" v="lcn"/>
  <tag k="ref" v="$number"/>
  <tag k="name" v="$desc"/>
  </relation></osm>});
}


sub osm {
  my ($url, $user, $password) = @_;
  my $ua = LWP::UserAgent->new;

  return sub {
    my ($method, $action, $content) = @_;

    my $req = HTTP::Request->new($method => "$url/api/0.6/$action");
    $req->authorization_basic($user, $password);
    $req->content($content);
    my $res = $ua->request($req);

    if ($res->is_success) {
        return $res->content;
    }
    else {
        die $res->status_line, "\n" . $res->content;
    }

  };
}
