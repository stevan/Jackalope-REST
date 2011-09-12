#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Moose;
use Test::Jackalope::REST::ResourceRepositoryTestSuite;

BEGIN {
    use_ok('Jackalope::REST');
    use_ok('Jackalope::REST::Resource::Repository');
}

{
    package My::SimpleModel;
    use Moose;

    my %ID_COUNTERS;

    has 'db' => (
        is      => 'ro',
        isa     => 'HashRef',
        default => sub { +{} }
    );

    sub get_next_id { ++$ID_COUNTERS{ $_[0] . "" } }

    sub list {
        my $self = shift;
        return [ map { [ $_, $self->db->{ $_ } ] } sort keys %{ $self->db } ]
    }

    sub create {
        my ($self, $data) = @_;
        my $id = $self->get_next_id;
        $self->db->{ $id } = $data;
        return ( $id, $data );
    }

    sub get {
        my ($self, $id) = @_;
        return $self->db->{ $id };
    }

    sub update {
        my ($self, $id, $updated_data) = @_;
        $self->db->{ $id } = $updated_data;
    }

    sub delete {
        my ($self, $id) = @_;
        delete $self->db->{ $id };
    }

}


my $model = My::SimpleModel->new;
isa_ok( $model, 'My::SimpleModel' );
Jackalope::REST::Resource::Repository->meta->apply( $model );
does_ok( $model, 'Jackalope::REST::Resource::Repository' );

Test::Jackalope::REST::ResourceRepositoryTestSuite->new(
    fixtures => [
        { id => 1, body => { foo => 'bar'   } },
        { id => 2, body => { bar => 'baz'   } },
        { id => 3, body => { baz => 'gorch' } },
        { id => 4, body => { gorch => 'foo' } },
    ]
)->run_all_tests( $model );

done_testing;

