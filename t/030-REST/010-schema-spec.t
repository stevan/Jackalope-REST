#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Jackalope;
use Test::Jackalope::Fixtures;
use Test::Jackalope::Fixtures::Manager::REST;

BEGIN {
    use_ok('Jackalope::REST');
}

my $repo = Jackalope::REST->new->resolve(
    type => 'Jackalope::Schema::Repository'
);
isa_ok($repo, 'Jackalope::Schema::Repository');

my $fixtures = Test::Jackalope::Fixtures->new(
    fixture_manager => Test::Jackalope::Fixtures::Manager::REST->new,
    fixture_set     => 'REST',
    repo            => $repo
);

foreach my $type ( qw[ resource resource/ref service/crud ] ) {
    my $schema = $repo->get_compiled_schema_by_uri('jackalope/rest/' . $type)->compiled;
    validation_pass(
        $repo->validate(
            { '$ref' => 'jackalope/core/types/object' },
            $schema,
        ),
        '... validate the compiled ' . $type . ' type with the schema type'
    );
    $fixtures->run_fixtures_for_type( $type );
}

done_testing;