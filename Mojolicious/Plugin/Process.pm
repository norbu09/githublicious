package Mojolicious::Plugin::Process;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::UserAgent;
use Store::CouchDB;

sub register {
    my ( $plugin, $app, $conf ) = @_;

    # default values
    my $couch = Store::CouchDB->new(
        port  => $conf->{couch}->{port},
        db    => $conf->{couch}->{db},
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
            my $repo_conf = $config->{ $doc->{repository}->{name} };
            my @parts     = split( /\//, $doc->{ref} );
            my $branch    = pop(@parts);
            return unless $repo_conf->{branch} eq $branch;

            my $to = $repo_conf->{jabber_notify}
              || $conf->{jabber}->{chatroom};
            my $msg =
                'Processing commit in '
              . $doc->{repository}->{name} . ': "'
              . $doc->{head_commit}->{message}
              . '" from '
              . $doc->{head_commit}->{author}->{name};
            $self->send_jabber( $msg, $to );

            given ( $repo_conf->{test} ) {
                when ('Jenkins') {
                    $doc->{deploy} = $self->jenkins($repo_conf);
                }
                when ('TAP') { $self->tap( $repo_conf, $doc ); }
                default {
                    $app->log->warn( "No build type defined for your commit ["
                          . $doc->{_id}
                          . "]" );
                }
            }
            $doc->{deploy_time} = time;
            $couch->put_doc( { name => $doc->{_id}, doc => $doc } );
            return;
        },
    );
    $app->helper(
        jenkins => sub {
            my ( $self, $config ) = @_;
            return unless $config->{jenkins};
            my $ua = Mojo::UserAgent->new;
            return $ua->get( $config->{jenkins} )->res->body;
        }
    );
}

1;
