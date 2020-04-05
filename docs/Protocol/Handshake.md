# Services Byte

The services byte uses bit masks to declare support for various functionality.

- 0b10000000 declares that the node is accepting connections via a server socket.

Every other bit is currently unused.

# Handshake

`Handshake` is sent when two nodes form a new connection. It declares the current connection as the Live socket. It has a message length of 37-bytes; 1-byte protocol ID, the 1-byte network ID, 1-byte supported services, and 2-byte server port, and the 32-byte sender's Blockchain's tail Block's hash.

If a node sends it after connection, the expected response is a `BlockchainTail`.

# Syncing

`Syncing` is sent when two nodes form a new connection. It declares the current connection as the Sync socket. It has a message length of 37-bytes; the 1-byte network ID, 1-byte protocol ID, 1-byte supported services, 2-byte server port, and the 32-byte sender's Blockchain's tail Block's hash.

# Busy

`Busy` is sent when a node receives a connection, which it can accept, yet is unwilling to handle it due to the lack of some resource. It's a valid response to either handshake message, yet only to the initial handshake. Beyond the message byte, it is a clone of `Peers` (described in the Syncing documentation), enabling nodes who tried to connect, and failed, to learn of other nodes to try.

# BlockchainTail

`BlockchainTail` is the expected response to a `Handshake` or `Syncing` which was sent after the peers have already performed their initial handshake. It has a message length of 32 bytes; the 32-byte sender's Blockchain's tail Block's hash.
