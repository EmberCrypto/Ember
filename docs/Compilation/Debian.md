# This is a guide for any Debian based system.

### Dependencies

Ember requires Nim, Nimble, GMP, and LibSodium.

```
sudo apt-get install curl git libgmp3-dev libsodium-dev gtk+-3.0 webkit2gtk-4.0
curl https://nim-lang.org/choosenim/init.sh -sSf | sh
choosenim 0.19.0
nimble install https://github.com/EmberCrypto/BN ec_events https://github.com/EmberCrypto/WebView
nimble install finals nimcrypto rocksdb
```

### Ember

```
git clone https://github.com/EmberCrypto/Ember.git
cd Ember
nim c src/main.nim
```

If you want to build an optimized version, put `-d:release` after `c`. There's also a headless version which doesn't import any GUI files available via `-d:nogui`.

The binary will be available under `build/`.
