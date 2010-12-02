/* ============================================================================
   ___  _______  _______  ___   _  _______  ___      _______  _______  _______
  |   ||   _   ||       ||   | | ||   _   ||   |    |       ||       ||       |
  |   ||  |_|  ||       ||   |_| ||  |_|  ||   |    |   _   ||    _  ||    ___|
  |   ||       ||       ||      _||       ||   |    |  | |  ||   |_| ||   |___
 _|   ||       ||      _||     |_ |       ||   |___ |  |_|  ||    ___||    ___|
|     ||   _   ||     |_ |    _  ||   _   ||       ||       ||   |    |   |___
|_____||__| |__||_______||___| |_||__| |__||_______||_______||___|    |_______|
============================================================================ */

if (Test == undefined) function Test () {}

// ----------------------------------------------------------------------------
// Jackalope Tester
// ----------------------------------------------------------------------------

Test.Jackalope = function () {}
Test.Jackalope.prototype = {
    "validation_pass" : function(result, message) {
        if (result["error"] == undefined) {
            ok(true, message);
        }
        else {
            try { console.log( result ) } catch (e) {}
            ok(false, message);
        }
    },
    "validation_fail" : function(result, message) {
        if (result["error"] == undefined) {
            ok(false, message);
        }
        else {
            ok(true, message);
        }
    }
};

// ----------------------------------------------------------------------------
// Fixtures tester
// ----------------------------------------------------------------------------

Test.Jackalope.Fixtures = function (opts) {
    if (opts["fixture_dir"] == undefined) throw new Error ("You must specify a fixture_dir");
    if (opts["validator"]   == undefined) throw new Error ("You must specify a validator");
    this.fixture_dir = opts["fixture_dir"];
    this.validator   = opts["validator"];
}

Test.Jackalope.Fixtures.prototype = {
    "run_fixtures_for_type" : function (type) {
        var self   = this;
        var tester = new Test.Jackalope ();
        jQuery.ajax({
            "async"   : false,
            "url"     : (this.fixture_dir + type + '.json'),
            "error"   : function (xhr, status, error) { ok( false, "... failed to load fixtures for " + type ) },
            "success" : function (data) {
                var tests = JSON.parse(data);
                for (var i = 0; i < tests.length; i++) {
                    var test   = tests[i];
                    var schema = test["schema"];

                    for (var j = 0; j < test["pass"].length; j++) {
                        tester.validation_pass(
                            self.validator.validate( schema, test["pass"][j] ),
                            "... validation passed for " + test["pass"][j] + " against  " + schema["type"]
                        )
                    }

                    for (var k = 0; k < test["fail"].length; k++) {
                        tester.validation_fail(
                            self.validator.validate( schema, test["fail"][k] ),
                            "... validation failed correctly for " + test["fail"][k] + " against  " + schema["type"]
                        )
                    }
                }
            }
        })
    }
}