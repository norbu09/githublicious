package Mojolicious::Plugin::Process;
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

            my $to = $conf->{jabber_notify}
              || $conf->{jabber}->{chatroom};
            my $msg =
                'Processing commit in '
              . $doc->{repository}->{name} . ': "'
              . $doc->{head_commit}->{message}
              . '" from '
              . $doc->{head_commit}->{author}->{name};
            $self->send_jabber( $msg, $to );

            given ( $config->{test} ) {
                when ('Jenkins') { $doc->{deploy} = $self->jenkins($config); }
                when ('TAP') { $self->tap( $config, $doc ); }
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
