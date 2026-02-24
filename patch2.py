import re

with open("lib/Nats/JetStream.rakumod", "r") as f:
    code = f.read()

with open("lib/Nats/JetStream.rakumod.patch2", "r") as f:
    patch = f.read()

old_func_regex = r"#\| Pull Consumer: fetch messages continuously, looping infinitely using chunks of 100\.\nmulti method fetch\(Str \$stream-name, Str \$consumer-name, Int :\$expires\?, Bool :\$no-wait\?\) \{.*"

code = code[:code.find("#| Pull Consumer: fetch messages continuously")] + patch

with open("lib/Nats/JetStream.rakumod", "w") as f:
    f.write(code)
