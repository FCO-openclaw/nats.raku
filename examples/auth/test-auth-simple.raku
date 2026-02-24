use v6;
use Nats;

# Load modules directly since we're not installed
# use lib "lib";

# This test verifies that our authentication parameter generation works

sub MAIN() {
    say "Testing Nats Authentication Parameter Generation";
    say "-----------------------------------------------";
    
    # Test creating a client with token auth
    my $token_nats = Nats.new(token => "test_token");
    
    # Verify that the client has the correct auth object
    say "Testing Token Auth:";
    say "  Auth object type: ", $token_nats.auth.^name;
    say "  Token value: ", $token_nats.auth.token if $token_nats.auth ~~ Nats::Auth::Token;
    
    # Test creating a client with basic auth
    my $basic_nats = Nats.new(username => "test_user", password => "test_pass");
    
    # Verify that the client has the correct auth object
    say "Testing Basic Auth:";
    say "  Auth object type: ", $basic_nats.auth.^name;
    if $basic_nats.auth ~~ Nats::Auth::Basic {
        say "  Username: ", $basic_nats.auth.username;
        say "  Password: ", $basic_nats.auth.password;
    }
    
    # Simulate the connect method to verify the generated JSON
    # This is done by temporarily replacing the print method
    my class TestNats is Nats {
        has $.last-connect-params;
        method test-connect() {
            # Create a mock version of connect that stores the params
            my %connect-params = %(
                verbose => False,
                pedantic => False,
                lang => "raku",
                version => "0.0.1",
                protocol => 1,
            );
            
            # Add auth params if available
            if self.auth {
                %connect-params = |%connect-params, |self.auth.connect-params();
            }
            
            # Store the params for inspection
            $!last-connect-params = %connect-params;
            
            # Return the JSON that would be sent
            use JSON::Fast;
            to-json(:!pretty, %connect-params);
        }
    }
    
    my $test_token_client = TestNats.new(token => "token123");
    my $token_json = $test_token_client.test-connect();
    say "\nToken Auth CONNECT payload:";
    say "  ", $token_json;
    say "  Token param present: ", $test_token_client.last-connect-params<auth_token>:exists;
    say "  Token value correct: ", $test_token_client.last-connect-params<auth_token> eq "token123";
    
    my $test_basic_client = TestNats.new(username => "user123", password => "pass456");
    my $basic_json = $test_basic_client.test-connect();
    say "\nBasic Auth CONNECT payload:";
    say "  ", $basic_json;
    say "  Username param present: ", $test_basic_client.last-connect-params<user>:exists;
    say "  Password param present: ", $test_basic_client.last-connect-params<pass>:exists;
    say "  Username value correct: ", $test_basic_client.last-connect-params<user> eq "user123";
    say "  Password value correct: ", $test_basic_client.last-connect-params<pass> eq "pass456";
    
    say "\n✅ Authentication parameter generation test completed!";
}