package Wikidata::API;

use strict;
use warnings;

use Class::Utils qw(set_params);
use Error::Pure qw(err);
use JSON::XS qw(encode_json);
use MediaWiki::API;
use Unicode::UTF8 qw(decode_utf8);

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
	$self->{'lgname'} = undef;

	# Login password.
	$self->{'lgpassword'} = undef;

	# Process parameters.
	set_params($self, @params);

	if (ref $self->{'mediawiki_api'} ne 'MediaWiki::API') {
		err "Parameter 'mediawiki_api' must be a 'MediaWiki::API' instance."
	}
	$self->{'mediawiki_api'}->{'config'}->{'api_url'}
		= 'https://'.$self->{'mediawiki_site'}.'/w/api.php';

	# Login.
	if (defined $self->{'lgname'} && defined $self->{'lgpassword'}) {
		my $login_ret = $self->{'mediawiki_api'}->login({
			'lgname' => $self->{'lgname'},
			'lgpassword' => $self->{'lgpassword'},
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
	my ($self, $data_hr) = @_;

	my $res = $self->{'mediawiki_api'}->api({
		'action' => 'wbeditentity',
		'new' => 'item',
		'data' => $self->_data($data_hr),
		'token' => $self->{'_csrftoken'},
	});
	$self->_mediawiki_api_error($res, 'Cannot create item.');

	return $res;
}

sub _data {
	my ($self, $data_hr) = @_;

	if (! defined $data_hr) {
		return '{}';
	}

	my $data_json_hr = {};
	$self->_data_lang_values($data_hr, $data_json_hr, 'labels');
	$self->_data_lang_values($data_hr, $data_json_hr, 'descriptions');
	$self->_data_claims($data_hr, $data_json_hr);

	my $data = decode_utf8(JSON::XS->new->utf8->encode($data_json_hr));

	return $data;
}

sub _data_lang_values {
	my ($self, $data_hr, $data_json_hr, $data_key) = @_;

	if (! exists $data_hr->{$data_key}) {
		return;
	}

	foreach my $key (keys %{$data_hr->{$data_key}}) {
		$data_json_hr->{$data_key}->{$key} = {
			'language' => $key,
			'value' => $data_hr->{$data_key}->{$key},
		};
	}

	return;
}

sub _data_claims {
	my ($self, $data_hr, $data_json_hr) = @_;

	if (! exists $data_hr->{'claims'}) {
		return;
	}

	foreach my $key (keys %{$data_hr->{'claims'}}) {
		push @{$data_json_hr->{'claims'}},
			$self->_process_claim($key, $data_hr->{'claims'}->{$key});
	}

	return;
}

sub _process_claim {
	my ($self, $key, $value) = @_;

	if ($value =~ m/^Q\d+$/) {
		return {
			'mainsnak' => {
				'snaktype' => 'value',
				'property' => $key,
				'datavalue' => {
					'value' => {
						'id' => $value,
						'entity-type' => 'item',
						# numeric-id
					},
					'type' => 'wikibase-entityid',
				},
			},
			'type' => 'statement',
			'rank' => 'normal',
		};
	} elsif (ref $value eq 'ARRAY') {
		my @ret;
		foreach my $sub_value (@{$value}) {
			push @ret, $self->_process_claim($key, $sub_value);
		}
		return @ret;
	} elsif (ref $value eq '') {
		return {
			'mainsnak' => {
				'snaktype' => 'value',
				'property' => $key,
				'datavalue' => {
					'type' => 'string',
					'value' => $value,
				},
			},
			'type' => 'statement',
			'rank' => 'normal',
		};
	} else {
		err 'Unsupported value.';
	}

	return;
}

sub _mediawiki_api_error {
	my ($self, $res, $message) = @_;

	if (! defined $res) {
		err $message,
			'error_code' => $self->{'mediawiki_api'}->{'error'}->{'code'},
			'error_details' => $self->{'mediawiki_api'}->{'error'}->{'details'},
		;
	}

	return;
}

1;

__END__
