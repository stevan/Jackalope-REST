use strict;
use warnings;
use inc::Module::Install;

name 'Jackalope-REST';
all_from 'lib/Jackalope/REST.pm';
license 'perl';

requires 'Jackalope'                  => 0;
requires 'MooseX::NonMoose'           => 0;
requires 'HTTP::Throwable'            => 0.011;
requires 'Plack'                      => 0;
requires 'CGI::Expand'                => 0;
requires 'Try::Tiny'                  => 0;
requires 'Class::Load'                => 0;
requires 'Digest'                     => 0;
requires 'File::Spec::Unix'           => 0;
requires 'Scalar::Util'               => 0;

build_requires 'Test::More'            => 0;
build_requires 'Test::Moose'           => 0;
build_requires 'Test::Fatal'           => 0;
build_requires 'HTTP::Request::Common' => 0;

tests('t/*.t');

WriteAll();