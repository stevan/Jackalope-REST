#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Moose;
use Bread::Board;
use Plack::Test;
use HTTP::Request::Common qw[ GET PUT POST DELETE ];

BEGIN {
    use_ok('Jackalope::REST');
}

use Jackalope::REST::Resource::Repository::Simple;

my $j = Jackalope::REST->new;
my $c = container $j => as {

    service 'MySchema' => {
        id         => 'simple/person',
        title      => 'This is a simple person schema',
        extends    => { '$ref' => 'jackalope/rest/service/crud' },
        properties => {
            first_name => { type => 'string' },
            last_name  => { type => 'string' },
            age        => { type => 'integer', greater_than => 0 },
        }
    };

    typemap 'Jackalope::REST::Resource::Repository::Simple' => infer;

    service 'MyService' => (
        class        => 'Jackalope::REST::CRUD::Service',
        dependencies => {
            schema_repository   => 'type:Jackalope::Schema::Repository',
            resource_repository => 'type:Jackalope::REST::Resource::Repository::Simple',
            schema              => 'MySchema',
            serializer          => {
                'Jackalope::Serializer' => {
                    'format' => 'JSON'
                }
            }
        }
    );
};

my $service = $c->resolve( service => 'MyService' );
isa_ok($service, 'Jackalope::REST::CRUD::Service');
does_ok($service, 'Jackalope::REST::Service');

isa_ok($service->schema_repository, 'Jackalope::Schema::Repository');
isa_ok($service->resource_repository, 'Jackalope::REST::Resource::Repository::Simple');
does_ok($service->resource_repository, 'Jackalope::REST::Resource::Repository');
is_deeply($service->schema, {
    id         => 'simple/person',
    title      => 'This is a simple person schema',
    extends    => { '$ref' => 'jackalope/rest/service/crud' },
    properties => {
        first_name => { type => 'string' },
        last_name  => { type => 'string' },
        age        => { type => 'integer', greater_than => 0 },
    }
}, '... got the schema we expected');

my $app = $service->to_app;

my $serializer = $c->resolve(
    service    => 'Jackalope::Serializer',
    parameters => { 'format' => 'JSON' }
);

test_psgi( app => $app, client => sub {
    my $cb = shift;

    {
        my $req = HTTP::Request->new("OPTIONS" => "http://localhost/");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for list ');
        my $resource = $serializer->deserialize( $res->content );
        is( $resource->{id}, 'simple/person', '... got the right id');
        is( $resource->{version}, '92d7a5505ef467c56dc083961e335e48180b07468a4efdd78d4dd9015394a584', '... got the right version');
        is_deeply(
            $resource->{links},
            [
                { rel => 'create',      href => '/',       method => 'POST'    },
                { rel => 'describedby', href => '/',       method => 'OPTIONS' },
                { rel => 'list',        href => '/',       method => 'GET'     },
            ],
            '... got the right list of links'
        );
        is_deeply(
            [ sort keys %{ $resource->{body} } ],
            [ sort qw[ simple/person jackalope/core/hyperlink ]],
            '... got the right schemas in here'
        );
    }

    #diag("Listing resources (expecting empty set)");
    {
        my $req = GET("http://localhost/");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for list ');
        is_deeply(
           $serializer->deserialize( $res->content ),
           [],
            '... got the right value for list'
        );
    }

    #diag("POSTing resource");
    {
        my $req = POST("http://localhost/" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"first_name":"Stevan","last_name":"Little","age":37}'
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        is($res->header('Location'), '/1', '... got the right URL for the item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    first_name => "Stevan",
                    last_name  => "Little",
                    age        => 37,
                },
                version => 'fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2',
                links => [
                    { rel => "delete",      href => "/1",      method => "DELETE" },
                    { rel => "edit",        href => "/1",      method => "PUT"    },
                    { rel => "read",        href => "/1",      method => "GET"    }
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("Error check");
    {
        my $req = POST("http://localhost/" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"first_name":"Stevan","last_name":"Little"}'
        ));
        my $res = $cb->($req);
        is($res->code, 400, '... got the right status for this exception');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code      => 400,
                reason           => 'Bad Request',
                message          => 'Params failed to validate against data_schema',
                validation_error => {
                    error => '{ first_name: "Stevan", last_name: "Little" } did not pass properties check',
                    sub_errors => {
                        error => "property 'age' didn't exist"
                    }
                }
            },
            '... got the error we expected'
        );
    }

    #diag("Listing resources (expecting one in set)");
    {
        my $req = GET("http://localhost/");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for list');
        is_deeply(
            $serializer->deserialize( $res->content ),
            [
                {
                    id   => 1,
                    body => {
                        first_name => "Stevan",
                        last_name  => "Little",
                        age        => 37,
                    },
                    version => 'fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2',
                    links => [
                        { rel => "delete",      href => "/1",      method => "DELETE" },
                        { rel => "edit",        href => "/1",      method => "PUT"    },
                        { rel => "read",        href => "/1",      method => "GET"    }
                    ]
                },
            ],
            '... got the right value for list'
        );
    }

    #diag("GETing resource we just posted");
    {
        my $req = GET("http://localhost/1");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for read');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    first_name => "Stevan",
                    last_name  => "Little",
                    age        => 37,
                },
                version => 'fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2',
                links => [
                    { rel => "delete",      href => "/1",      method => "DELETE" },
                    { rel => "edit",        href => "/1",      method => "PUT"    },
                    { rel => "read",        href => "/1",      method => "GET"    }
                ]
            },
            '... got the right value for read'
        );
    }

    #diag("Error check");
    {
        my $req = GET("http://localhost/2");
        my $res = $cb->($req);
        is($res->code, 404, '... got the right status for not found');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code => 404,
                reason      => 'Not Found',
                message     => 'no resource for id (2)',
            },
            '... got the error we expected'
        );
    }

    #diag("PUTing updates to the resource we just posted");
    {
        my $req = PUT("http://localhost/1" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"id":"1","version":"fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2","body":{"first_name":"Stevan","last_name":"Little","age":38}}'
        ));
        my $res = $cb->($req);
        is($res->code, 202, '... got the right status for edit');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    first_name => "Stevan",
                    last_name  => "Little",
                    age        => 38,
                },
                version => '9d4a75302bb634edf050d6b838b050b978bea1460d5879618e8e3ae8c291247f',
                links => [
                    { rel => "delete",      href => "/1",      method => "DELETE" },
                    { rel => "edit",        href => "/1",      method => "PUT"    },
                    { rel => "read",        href => "/1",      method => "GET"    }
                ]
            },
            '... got the right value for edit'
        );
    }

    #diag("Error check");
    {
        my $req = PUT("http://localhost/1" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"id":"1","versi":"fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2","body":{"first_name":"Stevan","last_name":"Little","age":38}}'
        ));
        my $res = $cb->($req);
        is($res->code, 400, '... got the right status for this exception');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code      => 400,
                reason           => 'Bad Request',
                message          => 'Params failed to validate against data_schema',
                validation_error => {
                    error => '{ body: { age: 38, first_name: "Stevan", last_name: "Little" }, id: 1, versi: "fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2" } did not pass properties check',
                    sub_errors => {
                        error => "property 'version' didn't exist"
                    }
                }
            },
            '... got the error we expected'
        );
    }
    {
        my $req = PUT("http://localhost/2" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"id":"1","version":"fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2","body":{"first_name":"Stevan","last_name":"Little","age":38}}'
        ));
        my $res = $cb->($req);
        is($res->code, 400, '... got the right status for this exception');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code => 400,
                reason      => 'Bad Request',
                message     => 'the id does not match the id of the updated resource'
            },
            '... got the error we expected'
        );
    }
    {
        my $req = PUT("http://localhost/2" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"id":"2","version":"fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2","body":{"first_name":"Stevan","last_name":"Little","age":38}}'
        ));
        my $res = $cb->($req);
        is($res->code, 404, '... got the right status for not found');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code => 404,
                reason      => 'Not Found',
                message     => 'no resource for id (2)',
            },
            '... got the error we expected'
        );
    }
    {
        my $req = PUT("http://localhost/1" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"id":"1","version":"fe982ce14ce2b2a1c09762decdeb1522a1e0a2ca390673446c930ca5fd11d2","body":{"first_name":"Stevan","last_name":"Little","age":38}}'
        ));
        my $res = $cb->($req);
        is($res->code, 409, '... got the right status for this exception');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code => 409,
                reason      => 'Conflict',
                message     => 'resource submitted has out of date version',
            },
            '... got the error we expected'
        );
    }


    #diag("GETing resource we just updated");
    {
        my $req = GET("http://localhost/1" );
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for read');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    first_name => "Stevan",
                    last_name  => "Little",
                    age        => 38,
                },
                version => '9d4a75302bb634edf050d6b838b050b978bea1460d5879618e8e3ae8c291247f',
                links => [
                    { rel => "delete",      href => "/1",      method => "DELETE" },
                    { rel => "edit",        href => "/1",      method => "PUT"    },
                    { rel => "read",        href => "/1",      method => "GET"    }
                ]
            },
            '... got the right value for read'
        );
    }

    #diag("Errors");
    {
        my $req = DELETE("http://localhost/1" => (
            'If-Matches' => '9d4a75302bb63df050d6b838b050b978bea1460d5879618e8e3ae8c291247f'
        ));
        my $res = $cb->($req);
        is($res->code, 409, '... got the right status for this exception');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code => 409,
                reason      => 'Conflict',
                message     => 'resource submitted has out of date version',
            },
            '... got the error we expected'
        );
    }

    #diag("DELETEing resource we just updated (with conditional match)");
    {
        my $req = DELETE("http://localhost/1" => (
            'If-Matches' => '9d4a75302bb634edf050d6b838b050b978bea1460d5879618e8e3ae8c291247f'
        ));
        my $res = $cb->($req);
        is($res->code, 204, '... got the right status for delete');
        is_deeply( $res->content, '', '... got the right value for delete' );
    }

    #diag("Listing resources (expecting empty set)");
    {
        my $req = GET( "http://localhost/");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for list ');
        is_deeply(
           $serializer->deserialize( $res->content ),
           [],
            '... got the right value for list'
        );
    }

    #diag("POSTing resource");
    {
        my $req = POST("http://localhost/" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"first_name":"Stevan","last_name":"Little","age":37}'
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        is($res->header('Location'), '/2', '... got the right URL for the item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 2,
                body => {
                    first_name => "Stevan",
                    last_name  => "Little",
                    age        => 37,
                },
                version => 'fe982ce14ce2b2a1c097629adecdeb1522a1e0a2ca390673446c930ca5fd11d2',
                links => [
                    { rel => "delete",      href => "/2",      method => "DELETE" },
                    { rel => "edit",        href => "/2",      method => "PUT"    },
                    { rel => "read",        href => "/2",      method => "GET"    }
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("DELETEing resource we just updated (without conditional match)");
    {
        my $req = DELETE("http://localhost/2");
        my $res = $cb->($req);
        is($res->code, 204, '... got the right status for delete');
        is_deeply( $res->content, '', '... got the right value for delete' );
    }

    #diag("Listing resources (expecting empty set)");
    {
        my $req = GET( "http://localhost/");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for list ');
        is_deeply(
           $serializer->deserialize( $res->content ),
           [],
            '... got the right value for list'
        );
    }

    {
        my $req = PUT("http://localhost/");
        my $res = $cb->($req);
        is($res->code, 405, '... got the right status for bad method');
        is($res->header('Allow'), 'GET,OPTIONS,POST', '... got the right Allow header');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code     => 405,
                reason          => 'Method Not Allowed',
                message         => 'Method Not Allowed',
                allowed_methods => [ 'GET', 'OPTIONS', 'POST' ]
            },
            '... got the error we expected'
        );
    }

});


done_testing;