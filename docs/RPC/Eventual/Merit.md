# Merit Module

### `getHeight`

`getHeight` replies with the Blockchain's height. It takes in zero arguments and the result is an int of the height.

### `getDifficulty`

`getDifficulty` replies with the current difficulty. It takes in zero arguments and the result is a string of the difficulty.

### `getBlock`

`getBlock` replies with a Block. It takes in one argument.
- ID (int/string): Either the nonce as an int or hash as a string.

The result is an object, as follows:
- `hash`   (string)
- `header` (object)
  - `version`   (int)
  - `last`      (string)
  - `contents`  (string)
  - `significant` (int)
  - `sketchSalt`  (string)
  - `sketchCheck`  (string)
  - `miner`     (int/string): Either the miner's nick as an int or the key as a string if this is their first Block.
  - `time`      (int)
  - `proof`     (int)
  - `signature` (string)

- `transactions` (array of objects, each as follows)
  - `hash`    (string)
  - `holders` (array of ints)

- `elements` (array of objects, each as follows)
  - `descendant` (string)
  - `holder`     (int)

    When `descendant` == "SendDifficulty":
    - `nonce`      (int)
    - `difficulty` (int)

    When `descendant` == "DataDifficulty":
    - `nonce`      (int)
    - `difficulty` (int)

- `removals` (array of ints): Whoever got their Merit removed by this Block.

- `aggregate` (string)

### `getNickname`

`getNickname` replies with the Merit Holder's nickname. It takes in one argument.
- Merit Holder (string)

The result is an int of the nickname.

### `getPublicKey`

`getPublicKey` replies with the specified Merit Holder's BLS Public Key. It takes in one argument.
- Nickname (int)

The result is an string of the BLS Public Key.

### `getTotalMerit`

`getTotalMerit` replies with the total amount of Merit in existence. It takes in zero arguments and the result is an int of the total amount of Merit.

### `getUnlockedMerit`

`getUnlockedMerit` replies with the amount of Unlocked Merit in existence. It takes in zero arguments and the result is an int of the amount of Unlocked Merit.

### `getMerit`

`getMerit` replies with a Merit Holder's Merit. It takes in one argument.
- Merit Holder Nickname (int)

The result is an object, as follows:
- `status`    (string): "Unlocked", "Locked", or "Pending".
- `malicious` (bool): Whether or not this holder has a Merit Removal against them pending.
- `merit`     (int)

### `getBlockTemplate`

`getBlockTemplate` replies with a template for mining a Block. It takes in one argument.
- miner (string): BLS Public Key of the Miner.

The result is an object, as follows:
- `id`     (int): The template ID.
- `key`    (string): The RandomX cache key.
- `header` (string)
- `body`   (string)

Mining the Block occurs by hashing the header with a 4-byte proof appended. After the initial hash, the hash is signed by the miner, and the hash is hashed with the signature appended. If it beats the difficulty, it can be published by appending the 4-byte proof to the header, then appending the signature to the header, then appending the body to the completed header, and then calling `merit_publishBlock` with the ID (see below).

### `publishBlock`

`publishBlock` adds the Block to the local Blockchain, and if it's valid, publishes it. It takes in two arguments.
- ID    (int): The ID of a template. Only an ID from the last 5 templates is valid.
- Block (string): A Block serialized with a sketch capacity equivalent to the amount of included packets.

The result is a bool of true.
