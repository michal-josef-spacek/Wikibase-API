package Wikidata::API;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Error::Pure qw(err);
use JSON::XS qw(encode_json);
use MediaWiki::API;
use Unicode::UTF8 qw(decode_utf8);
use Wikidata::Content::Struct;

our $VERSION = 0.01;

# Constructor.
sub new {
	my ($class, @params) = @_;

	# Create object.
	my $self = bless {}, $class;

	# MediaWiki::API object.
	$self->{'mediawiki_api'} = MediaWiki::API->new;

	# MediaWiki site.
	$self->{'mediawiki_site'} = 'test.wikidata.org';

	# Login name.
	$self->{'login_name'} = undef;

	# Login password.
	$self->{'login_password'} = undef;

	# Process parameters.
	set_params($self, @params);

	if (ref $self->{'mediawiki_api'} ne 'MediaWiki::API') {
		err "Parameter 'mediawiki_api' must be a 'MediaWiki::API' instance."
	}
	$self->{'mediawiki_api'}->{'config'}->{'api_url'}
		= 'https://'.$self->{'mediawiki_site'}.'/w/api.php';

	# Login.
	if (defined $self->{'login_name'} && defined $self->{'login_password'}) {
		my $login_ret = $self->{'mediawiki_api'}->login({
			'lgname' => $self->{'login_name'},
			'lgpassword' => $self->{'login_password'},
		});
		$self->_mediawiki_api_error($login_ret, 'Cannot login.');
	}

	# Token.
	my $token_hr = $self->{'mediawiki_api'}->api({
		'action' => 'query',
		'meta' => 'tokens',
	});
	$self->_mediawiki_api_error($token_hr, 'Cannot get token.');
	$self->{'_csrftoken'} = $token_hr->{'query'}->{'tokens'}->{'csrftoken'};

	return $self;
}

sub create_item {
	my ($self, $wikidata_content) = @_;

	my $res = $self->{'mediawiki_api'}->api({
		'action' => 'wbeditentity',
		'new' => 'item',
		'data' => $self->_data($wikidata_content),
		'token' => $self->{'_csrftoken'},
	});
	$self->_mediawiki_api_error($res, 'Cannot create item.');

	return $res;
}

sub _data {
	my ($self, $wikidata_content) = @_;

	if (! defined $wikidata_content) {
		return '{}';
	} else {
		if (! $wikidata_content->isa('Wikidata::Content')) {
			err "Bad data. Must be 'Wikidata::Content' object.";
		}
	}

	my $data_json_hr = Wikidata::Content::Struct->new->serialize($wikidata_content);

	my $data = decode_utf8(JSON::XS->new->utf8->encode($data_json_hr));

	return $data;
}

sub _mediawiki_api_error {
	my ($self, $res, $message) = @_;

	if (! defined $res) {
		err $message,
			'Error code' => $self->{'mediawiki_api'}->{'error'}->{'code'},
			'Error details' => $self->{'mediawiki_api'}->{'error'}->{'details'},
		;
	}

	return;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Wikidata::API - Class for API to Wikidata (Wikibase) system.

=head1 SYNOPSIS

 use Wikidata::API;

 my $obj = Wikidata::API->new(%params);
 my $res = $obj->create_item($wikidata_content);

=head1 METHODS

=head2 C<new>

 my $obj = Wikidata::API->new(%params);

Constructor.

Returns instance of object.

=over 8

=item * C<mediawiki_api>

MediaWiki::API object.

Default value is MediaWiki::API->new.

=item * C<mediawiki_site>

MediaWiki site.

Default value is 'test.wikidata.org'.

=item * C<login_name>

Login name.

Default value is undef.

=item * C<login_password>

Login password.

Default value is undef.

=back

=head2 C<create_item>

 my $res = $obj->create_item($wikidata_content)

Create item in system.
C<$wikidata_content> is Wikidata::Content instance.

Returns reference to hash like this:

 {
         'entity' => {
                 ...
         },
         'success' => __STATUS_CODE__,
 }

=head1 ERRORS

 new():
         From Class::Utils::set_params():
                 Unknown parameter '%s'.
         Cannot login.
                 Error code: %s
                 Error details: %s
         Cannot get token.
                 Error code: %s
                 Error details: %s

 create_item():
         Bad data. Must be 'Wikidata::Content' object.

=head1 EXAMPLE

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

=head1 DEPENDENCIES

L<Class::Utils>,
L<Error::Pure>,
L<JSON::XS>,
L<MediaWiki::API>,
L<Unicode::UTF8>,
L<Wikidata::Content::Struct>.

=head1 SEE ALSO

=over

=item L<Wikidata::Content>

Wikidata content class.

=back

=head1 REPOSITORY

L<https://github.com/michal-josef-spacek/Wikidata-API>

=head1 AUTHOR

Michal Josef Špaček L<mailto:skim@cpan.org>

L<http://skim.cz>

=head1 LICENSE AND COPYRIGHT

© Michal Josef Špaček 2020

BSD 2-Clause License

=head1 VERSION

0.01

=cut
