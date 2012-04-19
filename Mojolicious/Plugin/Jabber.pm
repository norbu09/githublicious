package Mojolicious::Plugin::Jabber;

use Mojo::Base 'Mojolicious::Plugin';
use EV;
use AnyEvent;
use AnyEvent::XMPP::Client;
use AnyEvent::XMPP::Ext::Disco;
use AnyEvent::XMPP::Ext::Version;
use AnyEvent::XMPP::Ext::MUC;
use AnyEvent::XMPP::Ext::MUC::Message;

sub register {
    my ( $self, $app, $params ) = @_;

    my $j  = AE::cv;
    my $cl = AnyEvent::XMPP::Client->new();

    $app->helper(
        start_jabber => sub {
            my ($self) = @_;
            $cl->add_account( $params->{user}, $params->{pass} );
            $cl->reg_cb(
                session_ready => sub {
                    my ( $cl, $acc ) = @_;
                    $app->log->debug("Connected to jabber server");
                },
                disconnect => sub {
                    my ( $cl, $acc, $h, $p, $reas ) = @_;
                    $j->broadcast;
                },
                error => sub {
                    my ( $cl, $acc, $err ) = @_;
                    $app->log->error( "ERROR: " . $err->string );
                },
            );
            $cl->start;
        },
    );
    $app->helper(
        send_jabber => sub {
            my ( $self, $msg, $to ) = @_;
            my $cnf = 1 if ( $to =~ m{conference} );
            $cl->send_message( $msg => $to, undef, 'chat' );
        },
    );
}

1;
