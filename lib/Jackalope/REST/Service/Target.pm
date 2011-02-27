package Jackalope::REST::Service::Target;
use Moose::Role;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

use utf8 ();

use Jackalope::REST::Error::BadRequest;
use Jackalope::REST::Error::BadRequest::ValidationError;
use Jackalope::REST::Error::UnsupportedMediaType;

use Plack::Request;
use Jackalope::REST::Util::HashExpander 'expand_hash';

has 'service' => (
    is       => 'ro',
    does     => 'Jackalope::REST::Service',
    required => 1,
    handles  => [qw[
        schema_repository
        serializer
    ]]
);

has 'link' => (
    is       => 'ro',
    isa      => 'HashRef',
    required => 1
);

requires 'execute';

sub to_app {
    my $self = shift;
    return sub {
        my $env = shift;
        $self->execute(
            Plack::Request->new( $env ),
            map { values %{ $_ } } @{ $env->{'jackalope.router.match.mapping'} }
        );
    }
}

sub process_psgi_output {
    my ($self, $psgi) = @_;

    return $psgi unless scalar @{ $psgi->[2] };

    push @{ $psgi->[1] } => ('Content-Type' => $self->serializer->content_type);

    $psgi->[2]->[0] = $self->serializer->serialize( $psgi->[2]->[0] );

    if ( utf8::is_utf8( $psgi->[2]->[0] ) ) {
        utf8::encode( $psgi->[2]->[0] );
    }

    $psgi;
}

## Schema Checking

sub sanitize_and_prepare_input {
    my ($self, $r ) = @_;
    $self->check_uri_schema( $r );
    $self->check_data_schema( $r );
}

sub check_uri_schema {
    my ($self, $r) = @_;
    # look for a uri-schema ...
    if ( exists $self->link->{'uri_schema'} ) {
        my $mapping = +{ map { %{ $_ } } @{ $r->env->{'jackalope.router.match.mapping'} } };
        # since we have the 'uri_schema',
        # we can check the mappings against it
        foreach my $key ( keys %{ $self->link->{'uri_schema'} } ) {
            unless (exists $mapping->{ $key }) {
                Jackalope::REST::Error::BadRequest->throw(
                    message => "Required URI Param '$key' did not exist"
                );
            }
            my $result = $self->schema_repository->validate(
                $self->link->{'uri_schema'}->{ $key },
                $mapping->{ $key }
            );
            if ($result->{'error'}) {
                Jackalope::REST::Error::BadRequest::ValidationError->throw(
                    validation_error => $result,
                    message          => "URI Params failed to validate against uri_schema"
                );
            }
        }
    }
}

sub check_data_schema {
    my ($self, $r) = @_;

    my $params;
    # we know we are expecting data
    # if there is a 'data_schema' in the
    # link description, so we extract
    # the parameters based on the
    # 'method' specified
    if ( exists $self->link->{'data_schema'} ) {
        # should this default to GET?
        if ( $self->link->{'method'} eq 'GET' ) {
            $params = expand_hash( $r->query_parameters->as_hashref_mixed );
        }
        elsif ( $self->link->{'method'} eq 'POST' || $self->link->{'method'} eq 'PUT' ) {
            my $type = $r->content_type;
            if ( index( $type, $self->serializer->content_type ) != -1 ) {
                $params = $self->serializer->deserialize( $r->content );
            }
            elsif ( index( $type, 'application/x-www-form-urlencoded' ) != -1 ) {
                $params = expand_hash( $r->query_parameters->as_hashref_mixed );
            }
            elsif ( index( $type, 'multipart/form-data' ) != -1 ) {
                $params = expand_hash( $r->query_parameters->as_hashref_mixed );
                # now handle the uploads
                # if there are any
                if ( scalar $r->upload ) {
                    my $uploads = $r->uploads->as_hashref_mixed;
                    foreach my $key ( keys %$uploads ) {
                        $params->{ $key } = ref $uploads->{ $key } eq 'ARRAY'
                            ? [ map { $self->transform_upload( $_ ) } @{ $uploads->{ $key } } ]
                            : $self->transform_upload( $uploads->{ $key } );
                    }
                }
            }
            else {
                Jackalope::REST::Error::UnsupportedMediaType->throw(
                    message => "Could not process message of content-type ($type)"
                );
            }
        }

        # then, since we have the 'schema'
        # key, we can check the set of
        # params against it
        my $result = $self->schema_repository->validate( $self->link->{'data_schema'}, $params );
        if ($result->{'error'}) {
            Jackalope::REST::Error::BadRequest::ValidationError->throw(
                validation_error => $result,
                message          => "Params failed to validate against data_schema"
            );
        }
    }

    return $params;
}

sub check_target_schema {
    my ($self, $target) = @_;
    # if we have a target_schema
    # then we are expecting output
    if ( exists $self->link->{'target_schema'} ) {
        # check the output against the target_schema
        my $result = $self->schema_repository->validate( $self->link->{'target_schema'}, $target );
        if ($result->{'error'}) {
            Jackalope::REST::Error::BadRequest::ValidationError->throw(
                validation_error => $result,
                message          => "Output failed to validate against target_schema"
            );
        }
    }
    return $target;
}


sub transform_upload {
    my ($self, $upload) = @_;
    return +{
        size         => $upload->size,
        path_to_file => $upload->path,
        content_type => $upload->content_type,
        filename     => $upload->filename,
        basename     => $upload->basename
    }
}

no Moose::Role; 1;

__END__

=pod

=head1 NAME

Jackalope::REST::Service::Target - A Moosey solution to this problem

=head1 SYNOPSIS

  use Jackalope::REST::Service::Target;

=head1 DESCRIPTION

=head1 METHODS

=over 4

=item B<>

=back

=head1 BUGS

All complex software has bugs lurking in it, and this module is no
exception. If you find a bug please either email me, or add the bug
to cpan-RT.

=head1 AUTHOR

Stevan Little E<lt>stevan.little@iinteractive.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2010 Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
