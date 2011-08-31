# Jackalope-REST

Jackalope-REST is a framework for building REST style web services with embedded
hypermedia controls. It was heavily inspired by the description of "Level 3"
web services as described in [this article](http://martinfowler.com/articles/richardsonMaturityModel.html#level3)
by Martin Fowler and the book [REST in Practice](http://restinpractice.com/default.aspx).

### REST style web services

This part of Jackalope starts to get more opinionated. Jackalope-REST provides
all the building blocks for constructing a REST application using any kind of
custom workflow you would like.

We extend the base Jackalope spec for this part, adding to it a `web/resource` and
`web/resource/ref` schemas to help you manage your resources. And the
`jackalope/rest/service/read-only`, `jackalope/rest/service/non-editable` and
`jackalope/rest/service/crud` schemas, which can be extended to add a reasonable
set of default `linkrels` for a schema. These can all be seen in the
Jackalope::REST::Schema::Spec module.

These are the two core components of the REST part of Jackalope, Resources and
Services, which will discuss more below.

#### Resources

Within resources there are two key concepts; resources and resource repositories.
A resource is the transport format, it looks something like this:

    {
        id      : <string id>,
        body    : <data structure modeled by your schema>,
        version : <digest of the body>,
        links   : [ <array of hyperlink items> ]
    }

The `id` field is the lookup key for this given resource in the repository and the
`body` is what you have stored in the resource repository. The `version` is a digest
of the body constructed by creating an SHA-256 hash of the cannonical JSON of the body.
And then finally the optional `links` is an array of `hyperlink` items which represent
the other available services for this resource (ex: read, update, delete, etc.)

We also have a concept of resource references, which is a representation of a
reference to a resource. It looks something like this:

     {
        $id     : <string id>,
        type_of : <schema uri of resource this refers to>,
        version : <digest of the body of the resource this refers to>,
        link    : <hyperlink to read this resource>
     }

The `$id` field is the same as the `id` field in a resource, the `type_of` field
is the schema this `$id` refers too. Then optionally we have a `version`, which is
as described above and could be used in your code to check that the resource being
referred to has not changed. We also optionally have a `link`, which is an `hyperlink`
of the `read` service for this resource (basically a link to the resource itself).

The next concept is the resource repository. Currently we supply a basic role that will
wrap around your data repository and you only need worry about the `body` of the resource
and it will handle wrapping that into a proper resource as well as the generation and
checking the version string. This currently plugs in directly to the built-in CRUD
service, but can also be useful outside of that as well.

#### Services

Currently the services in Jackalope are really only building blocks, it is up to you
to assemble them in the way you need. The goal is to provide enough of a framework
so that mechanics of good HTTP friendly REST applications are easy and simple to
build. As this framework grows we will likely incorporate larger and more opinionated
building blocks to make development even easier.

# Jackalope-REST-CRUD

### REST style CRUD web services

This part of Jackalope starts to get even more opinionated. Jackalope-REST provides a
basic set of tools for exposing discoverable services and Jackalope-REST-CRUD provides
even more tools to manage a collection a resources in a CRUD like manner. It borrows
some of the basic HTTP interactions from the ATOM publishing protocol and Microsoft's
Cannonical REST Entity model, then mixed up with some of my personal opinions.

It should be noted that there is more to REST then simple CRUD actions on resource
collections. Jackalope-REST provides all the building blocks for constructing a
REST application using any kind of custom workflow you would like. However,
because CRUD is so common, currently it is available "out of the box" with
Jackalope-REST-CRUD.

#### CRUD Services

The services take a Jackalope schema as input, typically one that extends the
`jackalope/rest/service/crud` schema, and a resource repository and creates a web
service with the following features.

- options
    - This is done by doing a OPTIONS to the URI of a collection
    - The result is a resource wrapping the schema object used to create
      this service
        - It returns a 200 (OK) status code
        - the resource contains links to all the entry-points for this
          service, those typically are:
            - listing
            - creation
            - options
            - ... and any other linkrel in the schema which does not have
              a parameterized URI template for an href
- listing
    - This is done by doing a GET to the URI of a collection (/)
        - optional parameters are taken, which the connected resource repository
          can optionally handle
            - query : the search query
            - attrs : attributes such as `limit` and `skip`
    - The result is a list of resources, each with embedded hypermedia controls
        - It returns a 200 (OK) status code
- creation
    - Creation is done by doing a POST to the specified creation URI (/) with the body of a resource as the content
    - The newly created resource is returned in the body of the response
        - the resource will include links that provide hrefs for the various other actions
        - It returns a 201 (Created) status code
        - the response Location header provides the link to read the resource
- read
    - Reading is done by doing a GET the specified reading URI (/:id) with the ID for the resource embedded in the URL
    - The resource is returned in the body of the response
        - It returns a 200 (OK) status code
        - If the resource is not found it returns a 404 (Not Found) status code
- update
    - Updating is done by doing a PUT to the specified update URI (/:id) with ...
        - The resource id embedded in the URL
        - You need to PUT the full wrapped resource (minus the links metadata) so that it can test the version string to make sure it is in sync
    - the updated resource is sent back in the body of the request
        - It returns a 202 (Accepted) status code
        - If the resource is not found it returns a 404 (Not Found) status code
        - If the resource is out of sync (versions don't match), a 409 (Conflict) status is returned with no content
        - If the ID in the URL does not match the ID in the resource, a 400 (Bad Request) status is returned with no content
- delete
    - deletion is done by doing a DELETE to the specified deletion URI (/:id) with the ID for the resource embedded in the URL
        - It returns a 204 (No Content) status code
        - An optional If-Matches header is supported for version checking
            - it should contain the version string of the resource you want to delete and we will check it against the current one before deletion
            - if it does not match it returns a 409 (Conflict) status with no content

We also check to make sure that the proper HTTP method is used for the proper
URI and throw a 405 (Method Not Allowed) error with an `Allow` header properly
populated.

## Installation

To install this module type the following:

    perl Makefile.PL
    make
    make test
    make install

## Dependencies

This module requires these other modules and libraries:

    Jackalope
    Throwable::Error
    Plack
    JSON::XS
    Try::Tiny
    Class::Load
    Clone
    Digest
    File::Spec::Unix

    Test::More
    Test::Moose
    Test::Fatal
    HTTP::Request::Common

## Copyright and License

Copyright (C) 2010-2011 Infinity Interactive, Inc.

(http://www.iinteractive.com)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

## References

* [Richardson Maturity Model](http://martinfowler.com/articles/richardsonMaturityModel.html)
* [REST in Practice](http://restinpractice.com/default.aspx)
* [REST on Wikipedia](http://en.wikipedia.org/wiki/Representational_State_Transfer)
* [ATOM publishing protocol](http://www.atomenabled.org/)
* [HTTP Status Codes](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html)
* [Link relations](http://www.iana.org/assignments/link-relations/link-relations.xhtml)
* [Cannonical REST Entity](http://code.msdn.microsoft.com/cannonicalRESTEntity)


