# VCAM Bypass Tweak

This tweak hooks VCAM.dylib authorization flow for a locally owned/authorized jailbreak environment.

## Build

```bash
make package FINALPACKAGE=1
```

## Install

```bash
scp packages/*.deb root@iphone:/tmp/
ssh root@iphone 'dpkg -i /tmp/com.local.vcambypass_*.deb && sbreload'
```

## Target

- VCAM.dylib
- Classes: VCamVerifyManager, VCamMenuVC

## Notes

- Hooks are defensive: if original method signatures differ, tweak falls back to calling original where needed.
- The server endpoint extracted from VCAM is:
  `https://yz.xnsp.v200dd.eu.org/api.php`
