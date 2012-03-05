package Mojolicious::Plugin::Jenkins;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::UserAgent;

sub register {
    my ( $plugin, $app, $conf ) = @_;

    # default values

    $app->helper(
        process_commit => sub {
            my ( $couch, $doc ) = @_;
            my $config = $couch->get_view(
                {
                    view => 'repository/config',
                    opts => {
                        include_docs => 'true',
                        key          => $doc->{repository}->{name}
                    }
                }
            );
            return unless $config->{ $doc->{repository}->{name} };
            my $url = $config->{ $doc->{repository}->{name} }->{jenkins};
            return unless $url;
            my $ua = Mojo::UserAgent->new;
            $doc->{deploy} = $ua->get($url)->res->body;
            $couch->put_doc({doc => $doc});
        },
    );
}

1;
