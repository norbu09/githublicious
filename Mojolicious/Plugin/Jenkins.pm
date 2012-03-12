package Mojolicious::Plugin::Jenkins;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::UserAgent;
use Store::CouchDB;

sub register {
    my ( $plugin, $app, $conf ) = @_;

    # default values
    my $couch = Store::CouchDB->new(
        port  => $conf->{couch_port},
        db    => $conf->{couch_db},
        debug => 1,
    );

    $app->helper(
        process_commit => sub {
            my ( $self, $doc ) = @_;
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
            my $conf   = $config->{ $doc->{repository}->{name} };
            my @parts  = split( /\//, $doc->{ref} );
            my $branch = pop(@parts);
            return unless $conf->{branch} eq $branch;
            return unless $conf->{jenkins};
            my $ua = Mojo::UserAgent->new;
            $doc->{deploy}      = $ua->get( $conf->{jenkins} )->res->body;
            $doc->{deploy_time} = time;
            $couch->put_doc( { name => $doc->{_id}, doc => $doc } );
            return;
        },
    );
}

1;
