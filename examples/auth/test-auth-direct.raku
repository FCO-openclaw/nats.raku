use v6;

# Direct test for auth parameters

say "Testing Authentication Parameters";
say "-----------------------------";

# Test token parameter generation
my %token-params = %(auth_token => "test_token_123");
say "Token params: ", %token-params.raku;

# Test basic auth parameter generation
my %basic-params = %(user => "admin", pass => "password123");
say "Basic params: ", %basic-params.raku;

# Test JSON encoding of parameters
use JSON::Fast;
my $token-json = to-json(%token-params);
my $basic-json = to-json(%basic-params);

say "Token JSON: ", $token-json;
say "Basic JSON: ", $basic-json;

say "✅ Test completed!";