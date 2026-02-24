import re

with open("lib/Nats/JetStream.rakumod", "r") as f:
    code = f.read()

with open("lib/Nats/JetStream.rakumod.patch3", "r") as f:
    patch = f.read()

# Make sure we add use Nats::JetStream::Subscription at the top
if "use Nats::JetStream::Subscription" not in code:
    code = code.replace("use JSON::Fast;", "use JSON::Fast;\nuse Nats::JetStream::Subscription;")

code = code[:code.find("multi method fetch(Str $stream-name")] + patch

with open("lib/Nats/JetStream.rakumod", "w") as f:
    f.write(code)
