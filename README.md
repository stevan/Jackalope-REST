# Jackalope-REST

Jackalope-REST is a framework for building REST style web services with embedded
hypermedia controls. It was heavily inspired by the description of "Level 3"
web services as described in [this article](http://martinfowler.com/articles/richardsonMaturityModel.html#level3)
by Martin Fowler and the book [REST in Practice](http://restinpractice.com/default.aspx).

### REST style web services

This part of Jackalope starts to get more opinionated. Jackalope-REST provides
all the building blocks for constructing a REST application using any kind of
custom workflow you would like.

We extend the base Jackalope spec for this part, adding to it a 'web/resource' and
'web/resource/ref' schemas to help you manage your resources. And the
'jackalope/rest/service/read-only', 'jackalope/rest/service/non-editable' and
'jackalope/rest/service/crud' schemas, which can be extended to add a reasonable
set of default 'linkrels' for a schema. These can all be seen in the
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

The 'id' field is the lookup key for this given resource in the repository and the
'body' is what you have stored in the resource repository. The 'version' is a digest
of the body constructed by creating an SHA-256 hash of the cannonical JSON of the body.
And then finally the optional 'links' is an array of 'hyperlink' items which represent
the other available services for this resource (ex: read, update, delete, etc.)

We also have a concept of resource references, which is a representation of a
reference to a resource. It looks something like this:

     {
        $id     : <string id>,
        type_of : <schema uri of resource this refers to>,
        version : <digest of the body of the resource this refers to>,
        link    : <hyperlink to read this resource>
     }

The '$id' field is the same as the 'id' field in a resource, the 'type_of' field
is the schema this '$id' refers too. Then optionally we have a 'version', which is
as described above and could be used in your code to check that the resource being
referred to has not changed. We also optionally have a 'link', which is an 'hyperlink'
of the 'read' service for this resource (basically a link to the resource itself).

The next concept is the resource repository. Currently we supply a basic role that will
wrap around your data repository and you only need worry about the 'body' of the resource
and it will handle wrapping that into a proper resource as well as the generation and
checking the version string. This currently plugs in directly to the built-in CRUD
service, but can also be useful outside of that as well.

#### Services

Currently the services in Jackalope are really only building blocks, it is up to you
to assemble them in the way you need. The goal is to provide enough of a framework
so that mechanics of good HTTP friendly REST applications are easy and simple to
build. As this framework grows we will likely incorporate larger and more opinionated
building blocks to make development even easier.

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


