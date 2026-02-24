import re

with open("lib/Nats/JetStream.rakumod", "r") as f:
    code = f.read()

with open("lib/Nats/JetStream.rakumod.patch", "r") as f:
    patch = f.read()

# Replace everything from the old #| Pull Consumer comment down to the end of the file
old_func_regex = r"#\| Pull Consumer: fetch a batch of messages actively\nmethod fetch\(Str \$stream-name, Str \$consumer-name, Int :\$batch, Int :\$expires\?, Bool :\$no-wait\?\) \{.*"

# Instead of regex matching the entire file end, let's just find the exact old block and string replace
code = code[:code.find("#| Pull Consumer: fetch a batch of messages actively")] + patch

with open("lib/Nats/JetStream.rakumod", "w") as f:
    f.write(code)
