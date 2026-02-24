use Nats::Subscription;

class Nats::JetStream::Subscription is Nats::Subscription {
    has Int $.batch;
    has Bool $.continuous = False;
}
