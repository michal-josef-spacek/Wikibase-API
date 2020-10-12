#!/usr/bin/env perl

use strict;
use warnings;

use Data::Printer;
use Unicode::UTF8 qw(decode_utf8);
use Wikidata::Content;
use Wikidata::API;

# API object.
my $api = Wikidata::API->new;

# Content object.
my $c = Wikidata::Content->new;
$c->add_labels({
        'cs' => 'Douglas Adams',
        'en' => 'Douglas Adams',
});
$c->add_descriptions({
        'cs' => decode_utf8('anglický spisovatel, humorista a dramatik'),
        'en' => 'English writer and humorist',
});
my @aliases = (
        'Douglas Noel Adams',
        decode_utf8('Douglas Noël Adams'),
        'Douglas N. Adams',
);
$c->add_aliases({
        'cs' => \@aliases,
        'en' => \@aliases,
});
$c->add_claim_item({'P31' => 'Q5'});

# Create item.
my $res = $api->create_item($c);

# Print status:
print 'Success: '.$res->{'success'}."\n";

# Output:
# Success: 1