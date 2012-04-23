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
 
    my ($disco, $version, $muc, $acc);

    $app->helper(
        start_jabber => sub {
            my ($self) = @_;
            if ($params->{chatroom}) {
                $disco   = AnyEvent::XMPP::Ext::Disco->new;
                $version = AnyEvent::XMPP::Ext::Version->new;
                $muc     = AnyEvent::XMPP::Ext::MUC->new( disco => $disco );
            }
            $cl->add_account( $params->{user}, $params->{pass} );
            $cl->reg_cb(
                session_ready => sub {
                    my ( $cl, $_acc ) = @_;
                    $acc = $_acc;
                    $app->log->debug("Connected to jabber server");
                    if ($params->{chatroom}) {
                        $muc->join_room( $acc->connection, $params->{chatroom}, 'githublicious' );
                        $self->set_jabber_presence('boring ...');
                    }
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
            if($params->{chatroom}) {
                $to = $params->{chatroom};
                my $muc_msg = AnyEvent::XMPP::Ext::MUC::Message->new(
                    type => 'groupchat',
                    to   => $to,
                    body => $msg
                );
                $muc_msg->{connection} = $acc->connection,
                $muc_msg->{room} = $muc->get_room( $acc->connection, $to );
                $muc_msg->send();
            } else {
                $cl->send_message( $msg => $to, undef, 'chat' );
            }
        },
    );
    $app->helper(
        set_jabber_presence => sub {
            my ( $self, $presence ) = @_;
            $cl->set_presence( undef, $presence, 1 );
        },
    );
}

1;
