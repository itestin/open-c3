package api::approve;
use Dancer ':syntax';
use Dancer qw(cookie);
use Encode qw(encode);
use JSON qw();
use POSIX;
use MIME::Base64;
use api;
use Format;
use Util;

get '/approve/approval' => sub {
    my $user = $api::approvesso->run( cookie => cookie( 'sid' ), map{ $_ => request->headers->{$_} }qw( appkey appname ) );

    my @col = qw( id taskuuid uuid name opinion remarks create_time finishtime submitter oauuid notifystatus );
    my $r = eval{ 
        $api::mysql->query( 
            sprintf( "select %s from openc3_job_approval
                where user='$user' order by id desc limit 100", join( ',', @col ) ), \@col )};

    return +{ stat => $JSON::false, info => $@ } if $@;
    return +{ stat => $JSON::true, data => $r, xxx => sprintf( "select %s from openc3_job_approval  where user='$user' order by id desc limit 100", join( ',', @col ) ) };
};

post '/approve/approval' => sub {
    my $param = params();
    my $error = Format->new( 
        opinion => [ 'in', 'agree', 'refuse' ], 1,
        uuid => qr/^[a-zA-Z0-9]{12}$/, 1,
    )->check( %$param );

    return  +{ stat => $JSON::false, info => "check format fail $error" } if $error;

    my $user = $api::approvesso->run( cookie => cookie( 'sid' ), map{ $_ => request->headers->{$_} }qw( appkey appname ));

    eval{ $api::auditlog->run( user => $user, title => 'USR APPROVAL BY APPROVE WEB', content => "UUID:$param->{uuid} OPINION:$param->{opinion}" ); };
    return +{ stat => $JSON::false, info => $@ } if $@;

    my $time = POSIX::strftime( "%Y-%m-%d %H:%M:%S", localtime );
    my $r = eval{ $api::mysql->execute( "update openc3_job_approval set opinion='$param->{opinion}',finishtime='$time' where uuid='$param->{uuid}' and user='$user' and opinion='unconfirmed'")};

    return $@ ?  +{ stat => $JSON::false, info => $@ } : +{ stat => $JSON::true, data => \$r };
};

get '/approve/approval/:uuid' => sub {
    my $param = params();
    my $error = Format->new( 
        uuid => qr/^[a-zA-Z0-9]{12}$/, 1,
    )->check( %$param );

    return  +{ stat => $JSON::false, info => "check format fail $error" } if $error;

    my $user = $api::approvesso->run( cookie => cookie( 'sid' ), map{ $_ => request->headers->{$_} }qw( appkey appname ) );

    my @col = qw( id taskuuid name cont opinion remarks create_time finishtime submitter oauuid notifystatus user );
    my $r = eval{ 
        $api::mysql->query( 
            sprintf( "select %s from openc3_job_approval
                where taskuuid in ( select taskuuid from openc3_job_approval where user='$user' and uuid='$param->{uuid}')", join( ',', @col ) ), \@col )};

    return +{ stat => $JSON::false, info => $@ } if $@;
    return +{ stat => $JSON::true, data => $r };
};

true;
