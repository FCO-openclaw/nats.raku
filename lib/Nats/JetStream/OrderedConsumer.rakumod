use JSON::Fast;

unit class Nats::JetStream::OrderedConsumer;

has Str $.stream is required;
has Str $.name is required;
has Str $.deliver-policy = "new";
has Int $.start-seq;
has Str $.start-time;
has Int $.opt-start-seq;
has Bool $.flow-control = True;
has Int $.idle-heartbeat;
has Bool $.ordered = True;
has Str $.filter-subject;

method supply(--> Supply) {
    # Returns a supply that guarantees ordered delivery
    # Implementation would connect to JetStream and consume messages
    Supply.from-list([]);  # Placeholder
}
