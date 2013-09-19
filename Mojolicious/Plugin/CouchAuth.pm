package Mojolicious::Plugin::CouchAuth;

use Mojo::Base 'Mojolicious::Plugin';
use Store::CouchDB;
use Digest::SHA qw(sha256_base64);

sub register {
    my ( $self, $app, $params ) = @_;

    my $couch = Store::CouchDB->new(
        port => $params->{port},
        db   => $params->{db},
    );
    my $password_reset_timeout = 172800; # two days

    $app->helper(
        auth => sub {
            my ($self) = @_;

            return 1 if $self->session->{user_id};
            return unless $self->param('username');

            my $doc = _get_user($couch, $self->param('username'));
            return unless $doc;

            if (sha256_base64( $self->param('password') ) eq $doc->{password}){
                $self->session(name => $doc->{name});
                $self->session(user_id => $doc->{_id});
                $self->session(admin => 1) if (defined $doc->{role} && $doc->{role} eq 'admin');
                $self->session(last_login => _set_last_login($couch, $doc));
                return 1
            }
        },
    );
    $app->helper(
        is_admin => sub  {
            my ($self) = @_;

            my $doc = _get_user($couch, $self->param('username'));
            return unless $doc;

            return 1
              if (defined $doc->{role} && $doc->{role} eq 'admin');
        },
    );
    $app->helper(
        update_password => sub  {
            my ($self) = @_;
            my $doc = _get_user($couch, $self->param('username'));
            return unless $doc;
            $doc->{password} = sha256_base64( $self->param('password'));
            return $couch->put_doc({doc => $doc});
        },
    );
    $app->helper(
        add_password_reset => sub  {
            my $self = shift;

            my $user = _get_user($couch, $self->param('username'));
            return unless $user;
            my $doc = {
                username => $self->param('username'),
                type => 'password_reset',
                user => $user,
                ts => time,
            };
            my $id = $couch->put_doc({doc => $doc});
            return {id => $id, user => $user};
        },
    );
    $app->helper(
        get_password_reset => sub  {
            my ($self, $id) = @_;
            my $doc = $couch->get_doc({id => $id});
            return unless $doc;
            if($doc->{ts} + $password_reset_timeout > time){
                return $doc;
            } else {
                $couch->del_doc({id => $id});
            }
            return;
        },
    );
    $app->helper(
        expire_password_reset => sub  {
            my ($self, $id) = @_;
            return $couch->del_doc({id => $id});
        },
    );
    $app->helper(
        check_free => sub {
            my ($self, $username) = @_;
            return _get_user($couch, $username);
        },
    );
}

sub _get_user {
    my ($couch, $username) = @_;

    return $couch->get_doc({id => $username}) unless ($username =~ m/@/);

    my $docs = $couch->get_view({
            view   => 'site/user',
            opts   => { key => $username, include_docs => 'true' },
        });
    return $docs->{ $username };
}

sub _set_last_login {
    my ($couch, $doc) = @_;

    my $last_login = $doc->{last_login};
    $doc->{last_login} = time;
    $couch->put_doc({doc => $doc});
    return $last_login;
}

1;
