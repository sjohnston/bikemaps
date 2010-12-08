#!/usr/bin/perl

use feature 'say';
use DBI;
use Data::Dumper;
use LWP::UserAgent;
use YAML qw(LoadFile);

my $config = LoadFile('config.yaml');
my $osm_config = $config->{'OpenStreetMap'};

my $osm = osm(@{$osm_config}{qw(url user password)});

my @cords = ([-96.857073053268422,32.647614612663403],[-96.873859088030812,32.647547306235538],[-96.884413445630543,32.647574753495682],[-96.89133729501394,32.647476114368764]);

my $change = $osm->(PUT => 'changeset/create',
'<osm>
  <changeset>
    <tag k="created_by" v="Perl"/>
    <tag k="comment" v="Adding Dallas Cycle Routes"/>
  </changeset>
</osm>');
my $way = qq{<osm>
 <way changeset="$change">
   <tag k="note" v="Just a way"/>
};

foreach my $c (@cords) {
  my ($lon, $lat) = @$c;
  my $node = $osm->(PUT => 'node/create', qq{<osm><node changeset="$change" lat="$lat" lon="$lon"><tag k="note" v="Just a node"/></node></osm>});
  $way .= qq{<nd ref="$node" />\n};
}

$way .= '</way></osm>';
my $way = $osm->(PUT => 'way/create', $way);
$osm->(PUT => 'relation/create', qq{<osm><relation changeset="$change"><tag k="note" v="Just a relation"/>member type="way" ref="$way"/></relation></osm>});

$osm->(PUT => "changeset/$change/close");

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
