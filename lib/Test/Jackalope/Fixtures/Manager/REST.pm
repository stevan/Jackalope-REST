package Test::Jackalope::Fixtures::Manager::REST;
use Moose;
use Resource::Pack;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

extends 'Test::Jackalope::Fixtures::Manager';

has '+name' => ( default => __PACKAGE__ );
has '+fixtures_root' => (
    default => sub {
        Path::Class::File->new( __FILE__ )->parent->parent
    },
);

sub BUILD {
    my $self = shift;
    resource $self => as {
        resource 'REST' => as {
            install_from( $self->fixtures_root->subdir('REST') );

            file 'resource'     => 'resource.json';
            file 'resource_ref' => 'resource_ref.json';
            file 'service_crud' => 'service_crud.json';
        };
    };
}

__PACKAGE__->meta->make_immutable;

no Moose; no Resource::Pack; 1;


__END__

=pod

=head1 NAME

Test::Jackalope::Fixtures::Manager::REST - A Moosey solution to this problem

=head1 SYNOPSIS

  use Test::Jackalope::Fixtures::Manager::REST;

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

Copyright 2011 Infinity Interactive, Inc.

L<http://www.iinteractive.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
