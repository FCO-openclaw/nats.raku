import re

with open("lib/Nats/JetStream.rakumod", "r") as f:
    code = f.read()

with open("lib/Nats/JetStream.rakumod.patch5", "r") as f:
    patch = f.read()

# Replace content starting at the marker
code = code[:code.find("#| Continuous polling mode wrapper using expiration only. Yields a Nats::JetStream::Subscription built from batch sizes.")] + patch

with open("lib/Nats/JetStream.rakumod", "w") as f:
    f.write(code)
