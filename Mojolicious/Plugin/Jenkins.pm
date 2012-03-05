package Mojolicious::Plugin::Jenkins;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
	my ($plugin, $app, $conf) = @_;
	
	# default values
	
	$app->helper(
		process_commit => sub {
            my ($project, $doc) = @_;
            return;
        },
    );
}

1;
