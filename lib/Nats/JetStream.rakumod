use JSON::Fast;
use Nats::Message;

# Constantes principais
constant JS = '$JS';
constant JS-API = JS ~ '.API';
constant JS-ACK = JS ~ '.ACK';

# Stream Subjects
constant STREAM-CREATE     = JS-API ~ '.STREAM.CREATE.%s';
constant STREAM-INFO       = JS-API ~ '.STREAM.INFO.%s';
constant STREAM-DELETE     = JS-API ~ '.STREAM.DELETE.%s';
constant STREAM-LIST       = JS-API ~ '.STREAM.LIST';

# Consumer Subjects
constant CONSUMER-CREATE   = JS-API ~ '.CONSUMER.CREATE.%s.%s';
constant CONSUMER-INFO     = JS-API ~ '.CONSUMER.INFO.%s.%s';
constant CONSUMER-DELETE   = JS-API ~ '.CONSUMER.DELETE.%s.%s';
constant CONSUMER-MSG-NEXT = JS-API ~ '.CONSUMER.MSG.NEXT.%s.%s';

sub to-map($obj, *%pars --> Map()) {
    # Generate a map from object attributes using snake_case keys as expected by JetStream.
    # Convert hyphens in attribute names to underscores.
    $obj.^attributes.map: -> $attr {
        my $name = $attr.name.substr(2).subst: /'-'/, "_", :g;
        next if %pars{$name}:e && !%pars{$name};
        my $val = $attr.get_value: $obj;
        next unless $val ~~ Str | Int | Positional | Associative | Nil;
        $name => $val
    }
}

class Nats::Consumer {...}

class Nats::Stream {

    has       $.nats is required;
    has Str() $.name is required;
    has Str() @.subjects,
    has Str() $.retention = 'limits',
    has Str() $.storage = 'file',
    has Int() $.max-msgs = -1,
    has Int() $.max-bytes = -1,
    has Int() $.max-age = 0,
    has Str() $.discard = 'old',
    has Int() $.max-msg-size = -1,
    has Int() $.num-replicas = 1,

    #enum RetentionPolicy <limits interest work_queue>;
    #enum DiscardPolicy <old new>;
    #enum StorageType <file memory any>;
    ##enum Placement <>;
    #enum StoreCompression <none s2>;
    #
    #has $.nats;
    #
    #has Str              $!name                     is required;
    #has Str              @!subjects                 is required;
    #has Str              $!description;
    #has RetentionPolicy  $!retention;
    #has Int              $!max-consumers;
    #has Int              $!max-msgs;
    #has Int              $!max-bytes;
    #has Int              $!max-age;
    #has Int              $!max-msgs-per-subject;
    #has Int              $!max-msg-size;
    #has DiscardPolicy    $!discard;
    #has StorageType      $!storage;
    #has Int              $!num-replicas;
    #has Bool             $!no-ack;
    #has Str              $!template-owner;
    #has Int              $!duplicate-window;
    ##has Placement        $!placement;
    #has                  %!mirror;
    #has Associative      @!sources;
    #has StoreCompression $!compression;
    #has UInt             $!first-seq;

    method subject(Str $template, Str $stream? --> Str) {
        sprintf $template, |(.Str with $stream)
    }

    method create   { $!nats.request: $.subject(STREAM-CREATE, $!name), to-json self.&to-map }
    method info     { $!nats.request: $.subject(STREAM-INFO, $!name)   }
    method delete   { $!nats.request: $.subject(STREAM-DELETE, $!name) }
    method list     { $!nats.request: $.subject(STREAM-LIST)           }
    method consumer(Str $name, |c) { Nats::Consumer.new: |c, :$!nats, :$name, :stream($!name) }
}

class Nats::Consumer {
    has     $.nats is required;
    has Str $.name is required;
    has Str $.stream is required;
    has Str $.durable-name = $!name,
    has Str $.deliver-policy  = 'all',
    has Str $.ack-policy      = 'explicit',
    has Str $.filter-subject,
    has Str $.deliver-subject,
    has Int $.ack-wait        = 30,
    has Int $.max-deliver     = -1,
    # RENAME: JetStream API expects snake case 'max_ack_pending'. Keep attribute kebab, map correctly in config
    has Int $.max-ack-pending = 100,
    has Str $.replay-policy   = "instant",
    has Int $.num-replicas    = 0,

    method config(Bool :$include-durable = True --> Map()) {
        my %cfg = (
            ack_policy     => $!ack-policy,
            deliver_policy => $!deliver-policy,
            replay_policy  => $!replay-policy,
        );
        # The server rejects unknown fields; include only those supported and under the 'config' wrapper
        %cfg<max_ack_pending> = $!max-ack-pending if $!max-ack-pending.defined && $!max-ack-pending >= 0;
        # Omit fields not part of Consumer config in JS API (e.g., num_replicas is stream-level)
        # Only include max_deliver when positive; some servers reject unknown/negative values
        %cfg<max_deliver> = $!max-deliver if $!max-deliver.defined && $!max-deliver > 0;
        # Optional fields
        %cfg<filter_subject>  = $!filter-subject  if $!filter-subject.defined;
        %cfg<deliver_subject> = $!deliver-subject if $!deliver-subject.defined;
        %cfg<durable_name>    = $!durable-name    if $include-durable && $!durable-name.defined;
        # ack_wait expected in nanoseconds
        %cfg<ack_wait> = ($!ack-wait * 1_000_000_000) if $!ack-wait.defined && $!ack-wait > 0;
        %cfg.Map
    }

    method subject(Str $template, Str $stream, Str $consumer? --> Str) {
        sprintf $template, $stream, |(.Str with $consumer)
    }

    method create {
        # Stream-only endpoint; JetStream expects a wrapper with `stream_name` and `config`
        my $subject = JS-API ~ ".CONSUMER.CREATE." ~ $!stream;
        my %req = (
            stream_name => $!stream,
            config      => self.config,
        );
        $!nats.request: $subject, to-json %req.Map
    }

    method create-named {
        # Named endpoint; payload includes `stream_name` and wraps `config` without durable_name
        my $subject = $.subject(CONSUMER-CREATE, $!stream, $!name);
        my %req = (
            stream_name => $!stream,
            config      => self.config(:include-durable(False)),
        );
        $!nats.request: $subject, to-json %req.Map
    }

    method msgs(UInt :$expires, Bool :$no-wait, UInt :$batch) {
        # Build payload explicitly to avoid slips and ensure proper JSON
        my %payload;
        %payload<no_wait> = True if $no-wait;
        %payload<expires> = $expires * 1_000_000_000 if $expires;
        %payload<batch>   = $batch if $batch && $batch > 0;

        my $subj = $.subject: CONSUMER-MSG-NEXT, $!stream, $!name;

        supply {
            if $expires {
                whenever Promise.in($expires) { done }
            }
            loop {
                # Send JSON payload as required by JetStream API
                my $req = $!nats.request:
                    $subj,
                    to-json(%payload.elems ?? %payload !! %()),
                ;
                emit await $req
            }
        }
    }

    # Ack helper: explicit ack to the message reply subject
    method ack(Nats::Message $msg) {
        return unless $msg.^can('reply-to') && $msg.reply-to;
        $!nats.publish: $msg.reply-to, "+ACK";
    }

    # Ack with server confirmation (double-ack)
    method ack-sync(Nats::Message $msg) {
        return unless $msg.^can('reply-to') && $msg.reply-to;
        $!nats.request: $msg.reply-to, "+ACK";
    }

    # AckNext: request next messages on pull consumer via the message reply subject
    method ack-next(Nats::Message $msg, UInt :$batch = 1, Bool :$no-wait) {
        return unless $msg.^can('reply-to') && $msg.reply-to;
        my Str $payload = $no-wait
            ?? "+NXT " ~ to-json({ no_wait => True })
            !! "+NXT " ~ $batch;
        $!nats.publish: $msg.reply-to, $payload;
    }

    #sub consumer-info     { $.subject(CONSUMER-INFO, $!stream)      }
    #sub consumer-delete   { $.subject(CONSUMER-DELETE,)             }
}
