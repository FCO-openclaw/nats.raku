unit module Nats::Auth;

# Base class for all authentication mechanisms
class Base {
    # Method to generate auth parameters for CONNECT payload
    method connect-params(--> Hash) {
        # Default implementation returns empty hash (no auth)
        %()
    }
}

# Token-based authentication
class Token is Base {
    has Str $.token is required;
    
    method connect-params(--> Hash) {
        %( auth_token => $!token )
    }
}

# Basic username/password authentication
class Basic is Base {
    has Str $.username is required;
    has Str $.password is required;
    
    method connect-params(--> Hash) {
        %( 
            user => $!username, 
            pass => $!password 
        )
    }
}

# JWT/NKEY-based authentication (NATS 2.0+)
class JWT is Base {
    has Str $.jwt-path is required;
    has Str $.nkey-path;
    has Str $.nkey-seed;
    has Str $!jwt;
    has Str $!nkey;
    
    submethod TWEAK() {
        # Load JWT
        $!jwt = $!jwt-path.IO.slurp.chomp;
        
        # Load NKEY if path provided
        if $!nkey-path {
            $!nkey = $!nkey-path.IO.slurp.chomp;
        }
        # Or use the seed directly if provided
        elsif $!nkey-seed {
            $!nkey = $!nkey-seed;
        }
        else {
            die "Either nkey-path or nkey-seed must be provided";
        }
    }
    
    # Method to sign a nonce using NKEY
    method sign-nonce(Str $nonce) {
        # TODO: Implement ED25519 signing here
        # This will require either binding to libsodium or using Raku crypto
        die "NKEY signing not implemented yet";
    }
    
    method connect-params(--> Hash) {
        %( 
            jwt => $!jwt,
            # Signature will be added later when we receive the server nonce
        )
    }
    
    # This is a special method needed for JWT auth flow
    # It adds the signature to the connect params after receiving the server INFO
    method with-signature(Str $nonce --> Hash) {
        my %params = self.connect-params;
        %params<sig> = self.sign-nonce($nonce);
        return %params;
    }
}

# Factory function to create the appropriate auth object based on inputs
sub create-auth(
    :$token, 
    :$username, 
    :$password, 
    :$jwt-path, 
    :$nkey-path,
    :$nkey-seed,
) is export {
    with $token {
        Token.new(:$token)
    }
    elsif $username.defined && $password.defined {
        Basic.new(:$username, :$password)
    }
    elsif $jwt-path.defined && ($nkey-path.defined || $nkey-seed.defined) {
        JWT.new(
            :$jwt-path, 
            |(:$nkey-path if $nkey-path.defined),
            |(:$nkey-seed if $nkey-seed.defined)
        )
    }
    else {
        # Default to no auth
        Base.new
    }
}