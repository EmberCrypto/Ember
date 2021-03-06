# Personal Module

Every route in this module requires authentication.

### `setWallet`

`setWallet` creates a new Wallet using the passed in Mnemonic and password. This is irreversible and will delete the existing Wallet, having the node lose all access to the current Merit Holder and all funds.

Arguments:
- `mnemonic` (string; optional): Creates a new Mnemonic if omitted.
- `password` (string; optional): Defaults to "" if omitted, as according to the BIP 39 spec.

The result is a bool of true.

### `setAccount`

`setAccount` deletes the existing Wallet on the node, in an irreversible manner, losing all access to the current Merit Holder and all funds. It sets the Wallet to track the specified account, presumably one returned from `getAccount`. This will disable any operations requiring access to the private key, as well as all Merit Holder related operations. That said, this will preserve the functionality of address generation, `getTransactionTemplate`, and more, enabling Watch Wallet functionality.

Arguments:
- `key`       (string): Account public key to use in accordance with BIP 44.
- `chainCode` (string): Chain code to use in accordance with BIP 32.

The result is a bool of true.

### `getMnemonic`

`getMnemonic` replies with the Wallet's Mnemonic, without any password needed to use it. The result is a string of the Mnemonic.

### `getMeritHolderKey`

`getMeritHolderKey` replies with the BLS Private Key of the node's Merit Holder. The result is a string of the Private Key.

### `getMeritHolderNick`

`getMeritHolderKey` replies with the nickname of the node's Merit Holder. The result is an int of the nickname.

### `getAccount`

`getAccount` replies with the public key and chain code for the account being used from the node's HD Wallet.

The result is an object, as follows:
- `key`       (string)
- `chainCode` (string)

### `getAddress`

`getAddress` replies with an address derived from the seed.

Arguments:
- `index` (int; optional): Defaults to a sequential index for an address which has not received any funds.

The result is a string of the generated address.

### `send`

`send` creates and publishes a Send using the Wallet on the node.

Arguments:
- `outputs` (array of objects)
  - `address` (string)
  - `amount`  (string)
- `password` (string; optional): Defaults to "".

The result is a string of the hash.

### `data`

`data` creates and publishes a Data using the Wallet on the node.

Arguments:
- `hex`      (bool; optional):   Defaults to false. When true, data is treated as bytes, instead of as text.
- `data`     (string):           Must be at least 1 byte and at most 256 bytes.
- `password` (string; optional): Defaults to "".

The result is a string of the hash.

### `getUTXOs`

`getUTXOs` replies with every UTXO known to the node's Wallet. If you only want the UTXOs for a specific address, use `transactions_getUTXOs`.

The result is an array of objects, each as follows:
- `address` (string)
- `hash`    (string)
- `nonce`   (int)

### `getBalance`

`getBalance` replies with the sum of the value of every UTXO known to the node's Wallet, AKA its balance. If you only want the balance for a specific address, use `transactions_getBalance`.

The result is a string of the balance.

### `getTransactionTemplate`

`getTransactionTemplate` replies with a signable transaction template usable by a program with the relevant private keys.

Arguments:
- `outputs` (array of objects, each as follows)
  - `address` (string): Address to send to.
  - `amount`  (string): Amount to send.
- `from`   (array of strings; optional): Addresses to use the UTXOs of; must be part of the current Wallet.
- `change` (string; optional):           Address to use as change.

The result is an object, as follows:
- `type`   (string): Type of the Transaction.
- `inputs` (array of objects, each as follows)
  - `hash`   (string)
  - `nonce`  (int)
  - `change` (bool): If this is a change address.
  - `index`  (int):  Address index.
- `outputs` (array of objects, each as follows)
  - `key`    (string)
  - `amount` (string)
- `publicKey` (string): The public key this transaction will be checked against. Used to verify the correct private key is being used.
