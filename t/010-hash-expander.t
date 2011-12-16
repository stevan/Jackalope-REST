#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::Moose;

use Jackalope::REST::Util::HashExpander 'expand_hash';

is_deeply(
    expand_hash({
        "attrs:sort:0:_geo_distance:pin.location:0" => -70,
        "attrs:sort:0:_geo_distance:pin.location:1" => 40,
        "attrs:sort:0:_geo_distance:order"          => 'asc',
        "attrs:sort:0:_geo_distance:unit"           => 'km',
        "attrs:query:term:user"                     => 'kimchy',
    }),
    {
        attrs => {
            sort => [
                {
                    _geo_distance => {
                        'pin.location' => [-70, 40],
                        order          => "asc",
                        unit           => "km"
                    }
                }
            ],
            query => {
                term => { user => "kimchy" }
            }
        }
    },
    '... got the results we expected'
);



done_testing;