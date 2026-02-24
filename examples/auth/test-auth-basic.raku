use v6;
use Nats;
use Nats::Auth;

# Test Nats::Auth::Basic directly
my $basic-auth = Nats::Auth::Basic.new(username => "test_user", password => "test_password");
my %connect-params = $basic-auth.connect-params();

say "Testing Basic Auth Object:";
say "  Username: ", $basic-auth.username;
say "  Password: ", $basic-auth.password;
say "  Connect Params: ", %connect-params.raku;

# Verify parameters
if %connect-params<user> eq "test_user" && %connect-params<pass> eq "test_password" {
    say "✅ Basic auth parameters generated correctly";
} else {
    say "❌ Basic auth parameters incorrect";
    exit 1;
}

# Test creation through the factory method
my $auth-factory = Nats::Auth.create(username => "factory_user", password => "factory_pass");

if $auth-factory ~~ Nats::Auth::Basic && 
   $auth-factory.username eq "factory_user" && 
   $auth-factory.password eq "factory_pass" {
    say "✅ Auth factory created correct basic auth object";
} else {
    say "❌ Auth factory failed to create basic auth object";
    exit 1;
}

# Test integration with Nats client
say "\nCreating Nats client with basic auth...";
my $nats = Nats.new(username => "integration_user", password => "integration_pass");

# Verify that auth was set properly in the Nats object
if $nats.auth ~~ Nats::Auth::Basic && 
   $nats.auth.username eq "integration_user" && 
   $nats.auth.password eq "integration_pass" {
    say "✅ Nats client created with proper basic authentication";
} else {
    say "❌ Failed to set basic auth in Nats client";
    exit 1;
}

say "\nAll Basic Auth tests passed successfully! ✅";

# Note: This test doesn't actually connect to a NATS server since we just want to validate
# the parameter generation, not the actual authentication flow.