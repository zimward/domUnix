#!/usr/bin/env nu
nix-build --impure -E "import ./test.nix {}" | scp $in doga:/tmp/test/root.erofs
nix-build --impure -E "import ./initrd.nix {}" | scp $"($in)/initrd" doga:/tmp/test/initrd
nix-build --impure -E "import ./kernel.nix {}" | scp $"($in)/bzImage" doga:/tmp/test/bzImage
ssh doga "chmod +w /tmp/test/*"
