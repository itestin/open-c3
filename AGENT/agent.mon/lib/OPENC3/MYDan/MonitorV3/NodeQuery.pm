package OPENC3::MYDan::MonitorV3::NodeQuery;

use warnings;
use strict;
use Carp;

use YAML::XS;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::HTTP;
use MIME::Base64;

my $monagent9100; BEGIN{ $monagent9100 = `c3mc-base-configx monagent9100` ? 1 : 0; };

my ( %proxy, %carry, %uexip );

sub new
{
    my ( $class, %this ) = @_;
    die "port undef" unless $this{port};

    bless \%this, ref $class || $class;
}

sub _html
{
    my ( $this, $content, $type ) = @_;
    $type ||= 'text/plain';
    my $length = length $content;
    my @h = (
        "HTTP/1.0 200 OK",
        "Content-Length: $length",
        "Content-Type: $type",
    );

    return join "\n",@h, "", $content;
}

sub getResponseProxy
{
    my ( $this, $content, $ip, $proxy, $url, $debug  ) = @_;
    my @debug;

    if( $debug )
    {
        my @carry;
        unless( $monagent9100 )
        {
            my $carry = $carry{$ip} ? MIME::Base64::decode_base64( $carry{$ip} ) : 'Null';

            $carry =   join "\n", map{ "# $_" }split /\n/, $carry;
            $proxy ||= 'Null';
            @carry =   ( "# CARRY:", $carry );
        }


        @debug = (
            "# DEBUG",
            "# monagent9100: $monagent9100",
            "# IP: $ip",
            "# PROXY: $proxy",
            "# URL: $url",
            @carry,
        );
    }

    $content = join "\n",
        "# HELP OPEN-C3 NodeQuery debug[$debug]",
        @debug,
        $content;

    return $this->_html( $content );
}

sub getResponseRoot
{
    my $this = shift;
    my $content = 
'
<html>
    <head><title>OPEN-C3 Node Query</title></head>
    <body>
        <h1>OPEN-C3 Node Query</h1>
    </body>
</html>
';

    return $this->_html( $content, 'text/html' );
}

my ( $index, %index ) = ( 0 );

sub run
{
    my $this = shift;

    #$AnyEvent::HTTP::TIMEOUT = 10;
    $AnyEvent::HTTP::MAX_PER_HOST = 512;
    my $cv = AnyEvent->condvar;
    tcp_server undef, $this->{port}, sub {
       my ( $fh ) = @_ or die "tcp_server: $!";

       my $idx = $index ++;
       $index{$idx} = +{ time => time };
       my $handle; $handle = new AnyEvent::Handle( 
           fh        => $fh,
           keepalive => 1,
           rbuf_max  => 1024000,
           wbuf_max  => 1024000,
           autocork  => 1,
           on_eof    => sub{
               printf "close $idx: timeoiut %s\n", time - $index{$idx}{time};
               $handle->destroy();
               delete $index{$idx};
           },
           on_read   => sub {
               my $self = shift;
               my $len = length $self->{rbuf};
               $self->push_read (
                   chunk => $len,
                   sub { 
                       my $data = $_[1];

                       if( $data =~ m#/query_([\d+\.\d+\.\d+\.\d+]+)_query# )
                       {
                           my $ip = $1;
                           $ip = $uexip{$ip} if $uexip{$ip};

                           if( $carry{$ip} && ref $carry{$ip} )
                           {
                               $carry{$ip} = encode_base64( YAML::XS::Dump $carry{$ip} );
                               $carry{$ip} =~ s/\n//g;
                           }

                           my $call = $proxy{$ip} || $ip;
                           my $uri = $proxy{$ip} ? "proxy_${ip}_proxy" : "metrics";
                           my $carry = $carry{$ip} ? "carry_$carry{$ip}_carry" : "";
                           my $debug = $data =~ /debug=1/ ? "debug=1" : "";

                           my $url = "http://$call:65110/$uri/$carry/$debug";
                           if( $monagent9100 )
                           {
                               if( $proxy{$ip} )
                               {
                                   $url = "http://$proxy{$ip}:65110/proxy_${ip}_proxy/conf_monagent9100_conf/$debug";
                               }
                               else
                               {
                                   $url = "http://$ip:9100/metrics";
                               }
                           }

                           return if $index{$idx}{http_get};
                           $index{$idx}{http_get} = http_get $url, sub { 
                               my $c = $_[0] || $_[1]->{URL}. " -> ".$_[1]->{Reason};
                               return if $handle && $handle->destroyed;
                               $handle->push_write($this->getResponseProxy($c, $ip, $proxy{$ip}, $url, $data =~ /debug=1/ ? 1 : 0 )) if $c;
                               $handle->push_shutdown();
                               $handle->destroy();
                               delete $index{$idx};
                           };
                       }
                       else
                       {
                           $handle->push_write($this->getResponseRoot());
                           $handle->push_shutdown();
                           $handle->destroy();
                           delete $index{$idx};
                       }
                    }
               );
           },
        );
    };

    my $proxyUpdate = AnyEvent->timer(
        after    => 3, 
        interval => 6,
        cb       => sub { 
            my $proxy = eval{ YAML::XS::LoadFile $this->{proxy} };

            if ( $@ ) { warn "load proxy file fail: $@"; return; }
            unless( $proxy && ref $proxy eq 'HASH' ) { warn "load proxy file no HASH"; return; }

            %proxy = %$proxy;
        }
    ) if $this->{proxy}; 

    my $carryUpdate = AnyEvent->timer(
        after    => 5, 
        interval => 6,
        cb       => sub { 
            my $carry = eval{ YAML::XS::LoadFile $this->{carry} };

            if ( $@ ) { warn "load carry file fail: $@"; return; }
            unless( $carry && ref $carry eq 'HASH' ) { warn "load carry file no HASH"; return; }

            %carry = %$carry;
        }
    ) if $this->{carry}; 

    my $uexipUpdate = AnyEvent->timer(
        after    => 7, 
        interval => 6,
        cb       => sub { 
            my $uexip = eval{ YAML::XS::LoadFile $this->{uexip} };

            if ( $@ ) { warn "load uexip file fail: $@"; return; }
            unless( $uexip && ref $uexip eq 'HASH' ) { warn "load uexip file no HASH"; return; }

            %uexip = %$uexip;
        }
    ) if $this->{uexip}; 

    $cv->recv;
}

1;
