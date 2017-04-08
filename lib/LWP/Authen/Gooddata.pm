package LWP::Authen::Gooddata;

use strict;
use warnings;

=head1 NAME

LWP::Authen::Gooddata - Handle GoodData HTTP authentication mechanism

=head1 SYNOPSIS

  use WWW::GoodData::Agent;
  my $agent = new WWW::GoodData::Agent ('https://secure.gooddata.com/gdc');
  $agent->post ('/gdc/account/login', ...);
  # The authentication cookie gets obtained transparently here
  $agent->get ('/gdc/md');

=head1 DESCRIPTION

B<LWP::Authen::Gooddata> gets loaded and invoked by a L<LWP::UserAgent>,
or its subclass such as L<WWW::GoodData::Agent>, upon reciept of 401
"Unauthorized" response from the server which indicates use of "GoodData"
authentization mechanism in the "WWW-Authenticate" header.

If the challenge indicates the temporary authentization cookie needs
to be refreshed it does so transparently and reissues the request,
otherwise dies with appropriate explanation.

=head1 METHODS

=over 4

=item B<authenticate> [PARAMS]

Called by LWP::UserAgent internally.

=cut

sub authenticate
{
	my ($class, $agent, $proxy, $challenge, $response,
		$request, $arg, $size) = @_;

	# Not an useful 401 from backend, pass the response
	return $response unless $challenge->{cookie};

	# Need to obtain super-secure token
	die 'Login required' if $challenge->{cookie} eq 'GDCAuthSST';

	# Everything else should be a token refresh
	die 'Required authentication not supported by client'
		if $challenge->{cookie} ne 'GDCAuthTT';

	# Get the token resource location
	my $token_uri = $challenge->{location};
	# Compat
	unless ($token_uri) {
		$token_uri = $request->uri->clone;
		$token_uri->path ($challenge->{location} or '/gdc/account/token');
		$token_uri->fragment (undef);
	}

	# Refresh the token
	$agent->{GDCAuthTT} = $agent->get (new URI ($token_uri),
		'X-GDC-AuthSST' => $agent->{GDCAuthSST})->{userToken}{token};

	$agent->default_header ('X-GDC-AuthTT' => $agent->{GDCAuthTT});
	$request->header (Cookie => '');

	# Retry the request
	return $agent->simple_request ($request);
}

=back

=head1 SEE ALSO

=over

=item *

L<http://developer.gooddata.com/api/auth.html> -- Specification of the GoodData authentization mechanism

=item *

L<LWP::UserAgent> -- The Perl HTTP agent

=back

=head1 BUGS

GoodData authentization mechanism is not an internet standard and thus
puts an interoperability barrier. Unfortunatelly, no standard and widely
supported mechanism provides comparable benefits (mostly server-side
performance coupled with sanity of implementation). Probably an alternative
mechanism should be provided (Basic or Digest, which are both widely
available) for the client to negotiate.

=head1 COPYRIGHT

Copyright 2011, 2012, 2013 Lubomir Rintel

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Lubomir Rintel C<lkundrak@v3.sk>

=cut

1;
