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

use Jackalope::REST::Application;
use Jackalope::REST::Resource::Repository::Simple;

my $j = Jackalope::REST->new;
my $c = container $j => as {

    service 'FooSchema' => {
        id         => 'simple/foo',
        extends    => { __ref__ => 'jackalope/rest/service/crud' },
        properties => { foo => { type => 'string' } }
    };

    service 'FooBarSchema' => {
        id         => 'simple/foo/bar',
        extends    => { __ref__ => 'jackalope/rest/service/crud' },
        properties => { foobar => { type => 'string' } }
    };

    typemap 'Jackalope::REST::Resource::Repository::Simple' => infer;

    service 'FooService' => (
        class        => 'Jackalope::REST::CRUD::Service',
        parameters   => { uri_base => { isa => 'Str', optional => 1 } },
        dependencies => {
            schema_repository   => 'type:Jackalope::Schema::Repository',
            resource_repository => 'type:Jackalope::REST::Resource::Repository::Simple',
            schema              => 'FooSchema',
            serializer          => {
                'Jackalope::Serializer' => {
                    'format' => 'JSON'
                }
            }
        }
    );

    service 'FooBarService' => (
        class        => 'Jackalope::REST::CRUD::Service',
        parameters   => { uri_base => { isa => 'Str', optional => 1 } },
        dependencies => {
            schema_repository   => 'type:Jackalope::Schema::Repository',
            resource_repository => 'type:Jackalope::REST::Resource::Repository::Simple',
            schema              => 'FooBarSchema',
            serializer          => {
                'Jackalope::Serializer' => {
                    'format' => 'JSON'
                }
            }
        }
    );
};

my $foo_service    = $c->resolve( service => 'FooService',    parameters => { uri_base => '/foo'     } );
my $foobar_service = $c->resolve( service => 'FooBarService', parameters => { uri_base => '/foo/bar' } );

isa_ok($foo_service, 'Jackalope::REST::CRUD::Service');
isa_ok($foobar_service, 'Jackalope::REST::CRUD::Service');

my $app = Jackalope::REST::Application->new(
    services => [
        $foo_service,
        $foobar_service,
    ]
)->to_app;

my $serializer = $c->resolve(
    service    => 'Jackalope::Serializer',
    parameters => { 'format' => 'JSON' }
);

test_psgi( app => $app, client => sub {
    my $cb = shift;

    my $resource;

    {
        my $req = POST("http://localhost/foo/bar" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"foobar":"FOOBAR"}'
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        $resource = $serializer->deserialize( $res->content );
    }

    {
        my $req = HTTP::Request->new("GET" => "http://localhost/foo");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for list ');
        my $result = $serializer->deserialize( $res->content );
        is( scalar @$result, 0, '... got nothing in here');
    }

    {
        my $req = HTTP::Request->new("GET" => "http://localhost/foo/bar");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for list ');
        my $result = $serializer->deserialize( $res->content );
        is( scalar @$result, 1, '... got the one item in here');
        is_deeply($result->[0], $resource, '... got the expected resource');
    }


});


done_testing;