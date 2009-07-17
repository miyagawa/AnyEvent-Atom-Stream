package AnyEvent::Atom::Stream::UserAgent;
use strict;
use AnyEvent;
use AnyEvent::HTTP;

sub new {
    my($class, $timeout, $on_disconnect) = @_;
    bless {
        timeout       => $timeout,
        on_disconnect => $on_disconnect,
    }, shift;
}

sub get {
    my($self, $url, %args) = @_;

    my $content_cb = delete $args{":content_cb"};
    http_get $url, want_body_handle => 1, sub {
        my($handle, $headers) = @_;
        Scalar::Util::weaken($self);

        my $final_cb = $self->{on_disconnect} || sub {};

        if ($handle) {
            my $disconn_cb = sub {
                undef $_[0];
                $final_cb->();
            };
            $handle->timeout($self->{timeout}) if $self;
            $handle->on_timeout($disconn_cb);
            $handle->on_eof($disconn_cb);
            $handle->on_read(sub {
                                 my $h = shift;
                                 local $XML::Atom::ForceUnicode = 1;
                                 $content_cb->(delete $h->{rbuf});
                             });

            $self->{guard} = AnyEvent::Util::guard {
                undef $content_cb; # refs AnyEvent::Atom::Stream
                undef $handle;
            };
        }
    }
}

1;

