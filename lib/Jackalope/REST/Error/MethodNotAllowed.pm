package Jackalope::REST::Error::MethodNotAllowed;
use Moose;
use MooseX::StrictConstructor;

our $VERSION   = '0.01';
our $AUTHORITY = 'cpan:STEVAN';

with 'HTTP::Throwable',
     'Jackalope::REST::Error',
     'HTTP::Throwable::Role::Status::MethodNotAllowed';

around 'pack' => sub {
    my $next = shift;
    my $self = shift;
    my $pack = $self->$next();
    $pack->{allowed_methods} = [ sort @{ $self->allow } ];
    $pack;
};

__PACKAGE__->meta->make_immutable;

no Moose; 1;

__END__

=pod

=head1 NAME

Jackalope::REST::Error::MethodNotAllowed - A Moosey solution to this problem

=head1 SYNOPSIS

  use Jackalope::REST::Error::MethodNotAllowed;

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
