use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
	module_name => 'WWW::GoodData',
	license => 'perl',
	dist_author => 'Michal Josef Spacek <skim@cpan.org>',
	meta_merge => {
		resources => {
			bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-GoodData',
			repository => 'https://github.com/tupinek/www-gooddata',
		}
	},
	configure_requires => {
		'Module::Build' => 0,
	},
	requires => {
		'Getopt::Long' => '2.36',
		'JSON' => 0,
		'Pod::Usage' => 0,
		'Text::ParseWords' => 0,
		'IO::Socket::SSL' => 0,
		'LWP::UserAgent' => 0,
	},
	build_requires => {
		'Test::Pod' => 0,
		'JSON' => 0,
	},
	recursive_test_files => 1,
);

$build->create_build_script;
