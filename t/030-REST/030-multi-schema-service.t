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

{
    package My::ShoppingCart::Repo;
    use Moose;
    use Clone 'clone';
    use Jackalope::REST::Error::NotImplemented;

    extends 'Jackalope::REST::Resource::Repository::Simple';

    has [ 'product_service', 'user_service' ] => (
        is       => 'ro',
        isa      => 'Jackalope::REST::CRUD::Service',
        required => 1,
    );

    sub list   { Jackalope::REST::Error::NotImplemented->throw(message => "List is not supported") }
    sub update { Jackalope::REST::Error::NotImplemented->throw(message => "Update is not supported") }

    sub create {
        my ($self, $data) = @_;
        my $id = $self->get_next_id;
        $self->db->{ $id } = $data;
        return ( $id, $self->inflate_user_and_items( clone( $data ) ) );
    }

    sub get {
        my ($self, $id) = @_;
        return unless $self->db->{ $id };
        return $self->inflate_user_and_items( clone( $self->db->{ $id } ) );
    }

    sub add_item {
        my ($self, $id, $data) = @_;
        my $cart = $self->db->{ $id };
        (defined $cart)
            || Jackalope::REST::Error::ResourceNotFound->throw(message => "no cart for id ($id)");
        push @{ $cart->{'items'} } => $data;
        return $self->wrap_data(
            $id,
            $self->inflate_user_and_items( clone( $cart ) )
        );
    }

    sub remove_item {
        my ($self, $id, $data) = @_;

        my $cart = $self->db->{ $id };
        $cart->{'items'} = [ grep { $_->{__id__} != $data->{__id__} } @{ $cart->{'items'} } ];
        return $self->wrap_data(
            $id,
            $self->inflate_user_and_items( clone( $cart ) )
        );
    }

    sub inflate_user_and_items {
        my ($self, $cart) = @_;

        my $user = $self->user_service->resource_repository->get_resource( $cart->{'user'}->{__id__} );
        $self->user_service->generate_links_for_resource(
            $user,
            $self->user_service->get_all_non_enpoint_links_from_schema
        );
        $cart->{'user'} = $user->pack;

        $cart->{'items'} = [
            map {
                my $product = $self->product_service->resource_repository->get_resource( $_->{__id__} );
                $self->product_service->generate_links_for_resource(
                    $product,
                    $self->product_service->get_all_non_enpoint_links_from_schema
                );
                $product->pack;
            } @{ $cart->{'items'} }
        ];

        $cart;
    }
}

{
    package My::ShoppingCart::Target::AddItem;
    use Moose;

    our $VERSION   = '0.01';
    our $AUTHORITY = 'cpan:STEVAN';

    with 'Jackalope::REST::CRUD::Service::Target::Role::RepositoryOperation';

    sub repository_operation { 'add_item' }
    sub operation_callback { [ 202, [], [ $_[1] ] ] }
}

{
    package My::ShoppingCart::Target::RemoveItem;
    use Moose;

    our $VERSION   = '0.01';
    our $AUTHORITY = 'cpan:STEVAN';

    with 'Jackalope::REST::CRUD::Service::Target::Role::RepositoryOperation';

    sub repository_operation { 'remove_item' }
    sub operation_callback { [ 202, [], [ $_[1] ] ] }
}

my $j = Jackalope::REST->new;
my $c = container $j => as {

    typemap 'Jackalope::REST::Resource::Repository::Simple' => infer;

    service 'ProductSchema' => {
        id         => "test/product",
        extends    => { __ref__ => 'jackalope/rest/service/crud' },
        properties => {
            sku  => { type => "string" },
            desc => { type => "string" }
        }
    };

    service 'ProductService' => (
        lifecycle    => 'Singleton',
        class        => 'Jackalope::REST::CRUD::Service',
        parameters   => { uri_base => { isa => 'Str', optional => 1 } },
        dependencies => {
            schema_repository   => 'type:Jackalope::Schema::Repository',
            resource_repository => 'type:Jackalope::REST::Resource::Repository::Simple',
            schema              => 'ProductSchema',
            serializer          => {
                'Jackalope::Serializer' => {
                    'format' => 'JSON'
                }
            }
        }
    );

    service 'UserSchema' => {
        id         => "test/user",
        extends    => { __ref__ => 'jackalope/rest/service/crud' },
        properties => {
            username => { type => "string" }
        }
    };

    service 'UserService' => (
        lifecycle    => 'Singleton',
        class        => 'Jackalope::REST::CRUD::Service',
        parameters   => { uri_base => { isa => 'Str', optional => 1 } },
        dependencies => {
            schema_repository   => 'type:Jackalope::Schema::Repository',
            resource_repository => 'type:Jackalope::REST::Resource::Repository::Simple',
            schema              => 'UserSchema',
            serializer          => {
                'Jackalope::Serializer' => {
                    'format' => 'JSON'
                }
            }
        }
    );

    service 'ShoppingCartSchema' => {
        id         => "test/shoppingcart",
        type       => "object",
        properties => {
            user => {
                extends    => { __ref__ => "jackalope/rest/resource" },
                properties => { body => { __ref__ => "test/user" } }
            },
            items  => {
                type  => "array",
                items => {
                    extends    => { __ref__ => "jackalope/rest/resource" },
                    properties => { body => { __ref__ => "test/product" } }
                }
            }
        },
        links => {
            # skipping the described-by, which you would do in real life ...
            create => {
                rel           => 'create',
                href          => '/',
                method        => 'POST',
                data_schema   => {
                    type       => 'object',
                    properties => {
                        user  => {
                            extends    => { __ref__ => 'jackalope/rest/resource/ref' },
                            properties => { type_of => { type => "string", literal => "test/user" } }
                        },
                        items => {
                            type  => 'array',
                            items => {
                                extends    => { __ref__ => 'jackalope/rest/resource/ref' },
                                properties => { type_of => { type => "string", literal => "test/product" } }
                            }
                        },
                    }
                },
                target_schema => {
                    type       => 'object',
                    extends    => { __ref__ => 'jackalope/rest/resource' },
                    properties => {
                        body => { __ref__ => '#' },
                    }
                },
            },
            read => {
                rel           => 'read',
                href          => '/:id',
                method        => 'GET',
                target_schema => {
                    type       => 'object',
                    extends    => { __ref__ => 'jackalope/rest/resource' },
                    properties => {
                        body => { __ref__ => '#' },
                    }
                },
                uri_schema    => {
                    id => { type => 'string' }
                }
            },
            add_item => {
                rel           => 'add_item',
                href          => '/:id/add_item',
                method        => 'PUT',
                data_schema   => {
                    extends    => { __ref__ => 'jackalope/rest/resource/ref' },
                    properties => { type_of => { type => "string", literal => "test/product" } }
                },
                target_schema => {
                    type       => 'object',
                    extends    => { __ref__ => 'jackalope/rest/resource' },
                    properties => {
                        body => { __ref__ => '#' },
                    }
                },
                uri_schema    => {
                    id => { type => 'string' }
                }
            },
            remove_item => {
                rel           => 'remove_item',
                href          => '/:id/remove_item',
                method        => 'PUT',
                data_schema   => {
                    extends    => { __ref__ => 'jackalope/rest/resource/ref' },
                    properties => { type_of => { type => "string", literal => "test/product" } }
                },
                target_schema => {
                    type       => 'object',
                    extends    => { __ref__ => 'jackalope/rest/resource' },
                    properties => {
                        body => { __ref__ => '#' },
                    }
                },
                uri_schema    => {
                    id => { type => 'string' }
                }
            },
            delete => {
                rel           => 'delete',
                href          => '/:id',
                method        => 'DELETE',
                uri_schema    => {
                    id => { type => 'string' }
                }
            }
        }
    };

    service 'ShoppingCartLinkRels' => {
        add_item    => 'My::ShoppingCart::Target::AddItem',
        remove_item => 'My::ShoppingCart::Target::RemoveItem'
    };

    service 'MyShoppingCartRepo' => (
        class        => 'My::ShoppingCart::Repo',
        dependencies => {
            product_service => 'ProductService',
            user_service    => 'UserService',
        }
    );

    service 'ShoppingCartService' => (
        lifecycle    => 'Singleton',
        class        => 'Jackalope::REST::CRUD::Service',
        parameters   => { uri_base => { isa => 'Str', optional => 1 } },
        dependencies => {
            schema_repository        => 'type:Jackalope::Schema::Repository',
            resource_repository      => 'MyShoppingCartRepo',
            schema                   => 'ShoppingCartSchema',
            linkrels_to_target_class => 'ShoppingCartLinkRels',
            serializer               => {
                'Jackalope::Serializer' => {
                    'format' => 'JSON'
                }
            }
        },
    );

};

my $product_service = $c->resolve( service => 'ProductService',      parameters => { uri_base => '/product' });
my $user_service    = $c->resolve( service => 'UserService',         parameters => { uri_base => '/user'    });
my $cart_service    = $c->resolve( service => 'ShoppingCartService', parameters => { uri_base => '/cart'    });

my $app = Jackalope::REST::Application->new(
    services => [
        $product_service,
        $user_service,
        $cart_service,
    ]
)->to_app;

my $serializer = $c->resolve(
    service    => 'Jackalope::Serializer',
    parameters => { 'format' => 'JSON' }
);

test_psgi( app => $app, client => sub {
    my $cb = shift;

    #diag("POST-ing user");
    {
        my $req = POST("http://localhost/user/" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"username":"stevan"}'
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        is($res->header('Location'), '/user/1', '... got the right URL for the item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    username => 'stevan'
                },
                version => '7f53a57fae8a7548af8677e60a46c2526d85569b1752ac679b376880bdd4f2a2',
                links => [
                    { rel => "delete",      href => "/user/1",        method => "DELETE" },
                    { rel => "edit",        href => "/user/1",        method => "PUT"    },
                    { rel => "read",        href => "/user/1",        method => "GET"    },
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("GET-ing user");
    {
        my $req = GET("http://localhost/user/1");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for read');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    username => 'stevan'
                },
                version => '7f53a57fae8a7548af8677e60a46c2526d85569b1752ac679b376880bdd4f2a2',
                links => [
                    { rel => "delete",      href => "/user/1",        method => "DELETE" },
                    { rel => "edit",        href => "/user/1",        method => "PUT"    },
                    { rel => "read",        href => "/user/1",        method => "GET"    },
                ]
            },
            '... got the right value for read'
        );
    }

    #diag("POST-ing product");
    {
        my $req = POST("http://localhost/product/" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"sku":"123456","desc":"disco-ball"}'
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        is($res->header('Location'), '/product/1', '... got the right URL for the item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    sku  => "123456",
                    desc => "disco-ball"
                },
                version => '07c302816348f4e67f0a8f3701aca90330c65a5030f48a2dbb891bcc6c18520d',
                links => [
                    { rel => "delete",      href => "/product/1",       method => "DELETE" },
                    { rel => "edit",        href => "/product/1",       method => "PUT"    },
                    { rel => "read",        href => "/product/1",       method => "GET"    },
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("POST-ing product");
    {
        my $req = POST("http://localhost/product/" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"sku":"227272","desc":"dancin-shoes"}'
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        is($res->header('Location'), '/product/2', '... got the right URL for the item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 2,
                body => {
                    sku  => "227272",
                    desc => "dancin-shoes"
                },
                version => 'd2e63b1870594d57bc16999e7f61e1f84fe91ba1cd47388a85d52fda206cb1cc',
                links => [
                    { rel => "delete",      href => "/product/2",       method => "DELETE" },
                    { rel => "edit",        href => "/product/2",       method => "PUT"    },
                    { rel => "read",        href => "/product/2",       method => "GET"    },
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("POST-ing product");
    {
        my $req = POST("http://localhost/product/" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"sku":"3838372","desc":"polyester-suit"}'
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        is($res->header('Location'), '/product/3', '... got the right URL for the item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 3,
                body => {
                    sku  => "3838372",
                    desc => "polyester-suit"
                },
                version => 'e13d199dae9e277e852c79b236106d4727ed52be9bee385c39fa66c9475aa4ff',
                links => [
                    { rel => "delete",      href => "/product/3",       method => "DELETE" },
                    { rel => "edit",        href => "/product/3",       method => "PUT"    },
                    { rel => "read",        href => "/product/3",       method => "GET"    },
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("POST-ing cart");
    {
        my $req = POST("http://localhost/cart/" => (
            'Content-Type' => 'application/json',
            'Content'      => $serializer->serialize({
                user  => { __id__ => '1', type_of => 'test/user' },
                items => [
                    { __id__ => '1', type_of => 'test/product' },
                    { __id__ => '2', type_of => 'test/product' }
                ]
            })
        ));
        my $res = $cb->($req);
        is($res->code, 201, '... got the right status for creation');
        is($res->header('Location'), '/cart/1', '... got the right URL for the item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    user => {
                        id   => 1,
                        body => {
                            username => 'stevan'
                        },
                        version => '7f53a57fae8a7548af8677e60a46c2526d85569b1752ac679b376880bdd4f2a2',
                        links => [
                        { rel => "delete",      href => "/user/1",        method => "DELETE" },
                        { rel => "edit",        href => "/user/1",        method => "PUT"    },
                        { rel => "read",        href => "/user/1",        method => "GET"    },
                        ]
                    },
                    items => [
                        {
                            id   => 1,
                            body => {
                                sku  => "123456",
                                desc => "disco-ball"
                            },
                            version => '07c302816348f4e67f0a8f3701aca90330c65a5030f48a2dbb891bcc6c18520d',
                            links => [
                                { rel => "delete",      href => "/product/1",       method => "DELETE" },
                                { rel => "edit",        href => "/product/1",       method => "PUT"    },
                                { rel => "read",        href => "/product/1",       method => "GET"    },
                            ]
                        },
                        {
                            id   => 2,
                            body => {
                                sku  => "227272",
                                desc => "dancin-shoes"
                            },
                            version => 'd2e63b1870594d57bc16999e7f61e1f84fe91ba1cd47388a85d52fda206cb1cc',
                            links => [
                                { rel => "delete",      href => "/product/2",       method => "DELETE" },
                                { rel => "edit",        href => "/product/2",       method => "PUT"    },
                                { rel => "read",        href => "/product/2",       method => "GET"    },
                            ]
                        }
                    ]
                },
                version => 'e38c3115a2ebcc1a466f79af4ada4a344aef0c50afbf68c84f910a884c5d370e',
                links => [
                { rel => "add_item",    href => "/cart/1/add_item",    method => "PUT"    },
                { rel => "delete",      href => "/cart/1",             method => "DELETE" },
                { rel => "read",        href => "/cart/1",             method => "GET"    },
                { rel => "remove_item", href => "/cart/1/remove_item", method => "PUT"    },
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("GET-ing cart");
    {
        my $req = GET("http://localhost/cart/1");
        my $res = $cb->($req);
        is($res->code, 200, '... got the right status for creation');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    user => {
                        id   => 1,
                        body => {
                            username => 'stevan'
                        },
                        version => '7f53a57fae8a7548af8677e60a46c2526d85569b1752ac679b376880bdd4f2a2',
                        links => [
                        { rel => "delete",      href => "/user/1",        method => "DELETE" },
                        { rel => "edit",        href => "/user/1",        method => "PUT"    },
                        { rel => "read",        href => "/user/1",        method => "GET"    },
                        ]
                    },
                    items => [
                        {
                            id   => 1,
                            body => {
                                sku  => "123456",
                                desc => "disco-ball"
                            },
                            version => '07c302816348f4e67f0a8f3701aca90330c65a5030f48a2dbb891bcc6c18520d',
                            links => [
                            { rel => "delete",      href => "/product/1",       method => "DELETE" },
                            { rel => "edit",        href => "/product/1",       method => "PUT"    },
                            { rel => "read",        href => "/product/1",       method => "GET"    },
                            ]
                        },
                        {
                            id   => 2,
                            body => {
                                sku  => "227272",
                                desc => "dancin-shoes"
                            },
                            version => 'd2e63b1870594d57bc16999e7f61e1f84fe91ba1cd47388a85d52fda206cb1cc',
                            links => [
                            { rel => "delete",      href => "/product/2",       method => "DELETE" },
                            { rel => "edit",        href => "/product/2",       method => "PUT"    },
                            { rel => "read",        href => "/product/2",       method => "GET"    },
                            ]
                        }
                    ]
                },
                version => 'e38c3115a2ebcc1a466f79af4ada4a344aef0c50afbf68c84f910a884c5d370e',
                links => [
                { rel => "add_item",    href => "/cart/1/add_item",    method => "PUT"    },
                { rel => "delete",      href => "/cart/1",             method => "DELETE" },
                { rel => "read",        href => "/cart/1",             method => "GET"    },
                { rel => "remove_item", href => "/cart/1/remove_item", method => "PUT"    },
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("PUT-ing a new item");
    {
        my $req = PUT("http://localhost/cart/1/add_item" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"__id__":"3","type_of":"test/product"}'
        ));
        my $res = $cb->($req);
        is($res->code, 202, '... got the right status for adding an item');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    user => {
                        id   => 1,
                        body => {
                            username => 'stevan'
                        },
                        version => '7f53a57fae8a7548af8677e60a46c2526d85569b1752ac679b376880bdd4f2a2',
                        links => [
                        { rel => "delete",      href => "/user/1",        method => "DELETE" },
                        { rel => "edit",        href => "/user/1",        method => "PUT"    },
                        { rel => "read",        href => "/user/1",        method => "GET"    },
                        ]
                    },
                    items => [
                        {
                            id   => 1,
                            body => {
                                sku  => "123456",
                                desc => "disco-ball"
                            },
                            version => '07c302816348f4e67f0a8f3701aca90330c65a5030f48a2dbb891bcc6c18520d',
                            links => [
                            { rel => "delete",      href => "/product/1",       method => "DELETE" },
                            { rel => "edit",        href => "/product/1",       method => "PUT"    },
                            { rel => "read",        href => "/product/1",       method => "GET"    },
                            ]
                        },
                        {
                            id   => 2,
                            body => {
                                sku  => "227272",
                                desc => "dancin-shoes"
                            },
                            version => 'd2e63b1870594d57bc16999e7f61e1f84fe91ba1cd47388a85d52fda206cb1cc',
                            links => [
                            { rel => "delete",      href => "/product/2",       method => "DELETE" },
                            { rel => "edit",        href => "/product/2",       method => "PUT"    },
                            { rel => "read",        href => "/product/2",       method => "GET"    },
                            ]
                        },
                        {
                            id   => 3,
                            body => {
                                sku  => "3838372",
                                desc => "polyester-suit"
                            },
                            version => 'e13d199dae9e277e852c79b236106d4727ed52be9bee385c39fa66c9475aa4ff',
                            links => [
                            { rel => "delete",      href => "/product/3",       method => "DELETE" },
                            { rel => "edit",        href => "/product/3",       method => "PUT"    },
                            { rel => "read",        href => "/product/3",       method => "GET"    },
                            ]
                        }
                    ]
                },
                version => '7834c825e1d5e0107d031879c85ca77e23e03af8113c2ee4b9f064963a679ca3',
                links => [
                { rel => "add_item",    href => "/cart/1/add_item",    method => "PUT"    },
                { rel => "delete",      href => "/cart/1",             method => "DELETE" },
                { rel => "read",        href => "/cart/1",             method => "GET"    },
                { rel => "remove_item", href => "/cart/1/remove_item", method => "PUT"    },
                ]
            },
            '... got the right value for creation'
        );
    }

    #diag("PUT-ing to delete the new item from cart");
    {
        my $req = PUT("http://localhost/cart/1/remove_item" => (
            'Content-Type' => 'application/json',
            'Content'      => '{"__id__":"3","type_of":"test/product"}'
        ));
        my $res = $cb->($req);
        is($res->code, 202, '... got the right status for removing an item');

        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                id   => 1,
                body => {
                    user => {
                        id   => 1,
                        body => {
                            username => 'stevan'
                        },
                        version => '7f53a57fae8a7548af8677e60a46c2526d85569b1752ac679b376880bdd4f2a2',
                        links => [
                        { rel => "delete",      href => "/user/1",        method => "DELETE" },
                        { rel => "edit",        href => "/user/1",        method => "PUT"    },
                        { rel => "read",        href => "/user/1",        method => "GET"    },
                        ]
                    },
                    items => [
                        {
                            id   => 1,
                            body => {
                                sku  => "123456",
                                desc => "disco-ball"
                            },
                            version => '07c302816348f4e67f0a8f3701aca90330c65a5030f48a2dbb891bcc6c18520d',
                            links => [
                            { rel => "delete",      href => "/product/1",       method => "DELETE" },
                            { rel => "edit",        href => "/product/1",       method => "PUT"    },
                            { rel => "read",        href => "/product/1",       method => "GET"    },
                            ]
                        },
                        {
                            id   => 2,
                            body => {
                                sku  => "227272",
                                desc => "dancin-shoes"
                            },
                            version => 'd2e63b1870594d57bc16999e7f61e1f84fe91ba1cd47388a85d52fda206cb1cc',
                            links => [
                            { rel => "delete",      href => "/product/2",       method => "DELETE" },
                            { rel => "edit",        href => "/product/2",       method => "PUT"    },
                            { rel => "read",        href => "/product/2",       method => "GET"    },
                            ]
                        },
                    ]
                },
                version => 'e38c3115a2ebcc1a466f79af4ada4a344aef0c50afbf68c84f910a884c5d370e',
                links => [
                { rel => "add_item",    href => "/cart/1/add_item",    method => "PUT"    },
                { rel => "delete",      href => "/cart/1",             method => "DELETE" },
                { rel => "read",        href => "/cart/1",             method => "GET"    },
                { rel => "remove_item", href => "/cart/1/remove_item", method => "PUT"    },
                ]
            },
            '... got the right value for creation'
        );
    }


    #diag("DELETE-ing cart (with conditional match)");
    {
        my $req = DELETE("http://localhost/cart/1/" => (
            'If-Matches' => 'e38c3115a2ebcc1a466f79af4ada4a344aef0c50afbf68c84f910a884c5d370e'
        ));
        my $res = $cb->($req);
        is($res->code, 204, '... got the right status for delete');
        is( $res->content, '', '... got the right value for delete' );
    }

    #diag("GET-ing cart (but get 404 because we deleted it)");
    {
        my $req = GET("http://localhost/cart/1");
        my $res = $cb->($req);
        is($res->code, 404, '... got the right status for creation');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code => 404,
                reason      => 'Not Found',
                message     => 'no resource for id (1)',
            },
            '... got the error we expected'
        );
    }

    {
        my $req = GET("http://localhost/foo");
        my $res = $cb->($req);
        is($res->code, 404, '... got the right status for creation');
        is_deeply(
            $serializer->deserialize( $res->content ),
            {
                status_code => 404,
                reason      => 'Not Found',
                message     => 'No service found at /foo',
            },
            '... got the error we expected'
        );
    }
});


done_testing;
