use v6;
use Nats;
use Nats::Auth;

# Test Nats::Auth::Token directly
my $token-auth = Nats::Auth::Token.new(token => "secret_token_123");
my %connect-params = $token-auth.connect-params();

say "Testing Token Auth Object:";
say "  Token: ", $token-auth.token;
say "  Connect Params: ", %connect-params.raku;

# Verify parameters
if %connect-params<auth_token> eq "secret_token_123" {
    say "✅ Token auth parameters generated correctly";
} else {
    say "❌ Token auth parameters incorrect";
    exit 1;
}

# Test creation through the factory method
my $auth-factory = Nats::Auth.create(token => "factory_token_456");

if $auth-factory ~~ Nats::Auth::Token && $auth-factory.token eq "factory_token_456" {
    say "✅ Auth factory created correct token object";
} else {
    say "❌ Auth factory failed to create token object";
    exit 1;
}

# Test integration with Nats client
say "\nCreating Nats client with token auth...";
my $nats = Nats.new(token => "integration_token_789");

# Verify that auth was set properly in the Nats object
if $nats.auth ~~ Nats::Auth::Token && $nats.auth.token eq "integration_token_789" {
    say "✅ Nats client created with proper token authentication";
} else {
    say "❌ Failed to set token auth in Nats client";
    exit 1;
}

say "\nAll Token Auth tests passed successfully! ✅";

# Note: This test doesn't actually connect to a NATS server since we just want to validate
# the parameter generation, not the actual authentication flow.