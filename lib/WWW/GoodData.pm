package WWW::GoodData;

=head1 NAME

WWW::GoodData - Client library for GoodData REST-ful API

=head1 SYNOPSIS

  use WWW::GoodData;
  my $gdc = new WWW::GoodData;
  print $gdc->get_uri ('md', { title => 'My Project' });

=head1 DESCRIPTION

B<WWW::GoodData> is the client for GoodData JSON-based API
built atop L<WWW::GoodData::Agent> client agent, with focus
on usefullness and correctness of implementation.

It  provides code for navigating the REST-ful API structure as well as
wrapper funcitons for common actions.

=cut

use strict;
use warnings;

use WWW::GoodData::Agent;
use URI;

our $root = new URI ('https://secure.gooddata.com/gdc');

=head1 METHODS

=over 4

=item B<new> [PARAMS]

Create a new client instance.

You can optionally pass a hash reference with properties that would be
blessed, otherwise a new one is created. Possible properties include:

=over 8

=item B<agent>

A L<WWW::GoodData::Agent> instance to use.

=back

=cut

sub new
{
	my $class = shift;
	my $self = shift || {};
	bless $self, $class;
	$self->{agent} ||= new WWW::GoodData::Agent ($root);
	$self->{agent}->{error_callback} = \&error_callback;
	return $self;
}

# API hierarchy traversal Cache
our %links;
sub get_links
{
	my $self = shift;
	my $root = ref $_[0] ? shift : $root;
	my @path = map { ref $_ ? $_ : { category => $_ } } @_;
	my $link = shift @path;

	unless ($links{$root}) {
		my $response = $self->{agent}->get ($root);
		# Various ways to get the links
		if (exists $response->{about}) {
			# Ordinary structure with about section
			$links{$root} = $response->{about}{links};
		} elsif (exists $response->{query} and exists $response->{query}{entries}) {
			# Inconsistent query entries
			$links{$root} = $response->{query}{entries};
		} elsif (scalar keys %$response == 1) {
			my @elements = ($response);
			my ($structure) = keys %$response;

			# Aggregated resources (/gdc/account/profile/666/projects)
			@elements = @{$response->{$structure}}
				if ref $response->{$structure} eq 'ARRAY';

			$links{$root} = [];
			foreach my $element (@elements) {
				my $root = $root;
				my ($type) = keys %$element;

				# Metadata with interesting information outside "links"
				if (exists $element->{$type}{links}{self}
					and exists $element->{$type}{meta}) {
					push @{$links{$root}}, {
						%{$element->{$type}{meta}},
						category => $type,
						structure => $structure,
						link => $element->{$type}{links}{self},
					};
					$root = $element->{$type}{links}{self};
				}

				# The links themselves
				foreach my $category (keys %{$element->{$type}{links}}) {
					my $link = $element->{$type}{links}{$category};
					push @{$links{$root}}, {
						structure => $structure,
						category => $category,
						type => $type,
						link => $link,
					};
				}
			}

		} else {
			die 'No links';
		}
	}

	my @matches = grep {
		my $this_link = $_;
		# Filter out those, who lack any of our keys or
		# hold a different value for it.
		not map { not exists $link->{$_}
			or not exists $this_link->{$_}
			or $link->{$_} ne $this_link->{$_}
			? 1 : () } keys %$link
	} @{$links{$root}};

	# Fully resolved
	return @matches unless @path;

	die 'Ambigious path' unless scalar @matches == 1;
	my $new_root = new URI ($matches[0]->{link});
	$new_root = $new_root->abs ($root);

	return $self->get_links ($new_root, @path);
}

=item B<links> PATH

Traverse the links in resource hierarchy following given PATH,
starting from API root (L</gdc> by default).

PATH is an array of dictionaries, where each key-value pair
matches properties of a link. If a plain string is specified,
it is considered to be a match against B<category> property:

  $gdc->get_links ('md', { 'category' => 'projects' });

The above call returns a list of all projects, with links to
their metadata resources.

=cut

sub links
{
	my @links = get_links @_;
	return @links if @links;
	%links = ();
	return get_links @_;
}

=item B<get_uri> PATH

Follows the same samentics as B<links>() call, but returns an
URI of the first matching resource instead of complete link
structure.

=cut

sub get_uri
{
	[links @_]->[0]{link};
}

=item B<login> EMAIL PASSWORD

Obtain a SST (login token).

=cut

sub login
{
	my $self = shift;
	my ($login, $password) = @_;

	$self->{login} = $self->{agent}->post ($self->get_uri ('login'),
		{postUserLogin => {
			login => $login,
			password => $password,
			remember => 0}});
}

=item B<projects>

Return array of links to project resources on metadata server.

=cut

sub projects
{
	my $self = shift;
	die 'Not logged in' unless $self->{login};
	$self->get_links (new URI ($self->{login}{userLogin}{profile}),
		qw/projects project/);
}

=item B<delete_project> IDENTIFIER

Delete a project given its identifier.

=cut

sub delete_project
{
	my $self = shift;
	my $project = shift;

	# Instead of directly DELETE-ing the URI gotten, we check
	# the existence of a project with such link, as a sanity check
	my $uri = $self->get_uri (new URI ($project),
		{ category => 'self', type => 'project' }) # Validate it's a project
		or die "No such project: $project";
	$self->{agent}->delete ($uri);
}

=item B<create_project> TITLE SUMMARY

Create a project given its title and optionally summary,
return its identifier.

=cut

sub create_project
{
	my $self = shift;
	my $title = shift or die 'No title given';
	my $summary = shift || '';

	# The redirect magic does not work for POSTs and we can't really
	# handle 401s until the API provides reason for them...
	$self->{agent}->get ($self->get_uri ('token'));

	return $self->{agent}->post ($self->get_uri ('projects'), {
		project => {
			# No hook to override this; use web UI
			content => { guidedNavigation => 1 },
			meta => {
				summary => $summary,
				title => $title,
			}
	}})->{uri};
}

=back

=head1 SEE ALSO

=over

=item *

L<http://developer.gooddata.com/api/> -- API documentation

=item *

L<https://secure.gooddata.com/gdc/> -- Browsable GoodData API

=item *

L<WWW::GoodData::Agent> -- GoodData API-aware user agent

=back

=head1 COPYRIGHT

Copyright 2011, Lubomir Rintel

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

Lubomir Rintel C<lkundrak@v3.sk>

=cut

1;
