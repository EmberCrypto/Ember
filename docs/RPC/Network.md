# Network Module

### `connect`

`connect` attempts to connect to another Meros node. It requires authentication.

Arguments:
- `address` (string): IP address or domain. Cannot be IPv6.
- `port`    (int):    Optional; defaults to 5132 if omitted.

The result is a bool of true.

### `getPeers`

`getPeers` replies with a list of every node Meros is currently connected it. The result is an array of objects, each as follows:
- `ip`     (string)
- `server` (bool)
- `port`   (int): Only present if the peer is a server.

### `broadcast`

`broadcast` broadcasts existing local data. Because it's already been processed locally, its presumably already been broadcasted around the network. This is meant to cover for any local networking issues/propagation shortcomings that may occur.

Arguments:
- `transaction` (string): Optional; hash of the Transaction to broadcast.
- `block`       (string): Optional; hash of the Block to broadcast.
- `element`     (object): Optional
  - `holder` (int)
  - `nonce`  (int)

The result is a bool of true.
