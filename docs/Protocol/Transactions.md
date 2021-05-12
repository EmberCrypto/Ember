# Transactions

Transactions is a DAG made up of Transactions, each defining inputs and outputs, with an additional two properties of sendDifficulty and dataDifficulty (256-bit hashes set via methods described in the Consensus documentation).

Every Transaction has the following fields:

- descendant: Transaction sub-type.
- inputs: Array of `(txHash, txOutputIndex)` which feed this Transaction.
- outputs: Array of `(key, amount)` which were created by this Transaction.
- hash: Blake2b-256 hash of the Transaction; each sub-type hashes differently.

The Transaction sub-types are as follows:

- Mint
- Claim
- Send
- Data

When a new Transaction is received via a `Claim`, `Send`, or `Data` message, it's added to the Transactions DAG, as long as it has at least one input and the checks imposed by the sub-type pass.

### Mint

Mint Transactions are locally created when Blocks are added to the Blockchain, as described in the Merit documentation, and are never sent over the network.

Mints have no inputs. It has one output per reward from the Epochs, where key is a Merit Holder's nickname and amount is the amount being minted to that Merit Holder.

The hash is the hash of the Block which created it.

### Claim

Claim Transactions are created in response to a Mint, and have the following additional field:

- signature: BLS Signature that proves the Merit Holder which earned the newly minted Meros wants this person to receive their reward.

Every Claim must have at least 1 input. Claim inputs must be Mint outputs who all output to the same sender. The Claim's singular output is to an Ristretto Public Key with the amount being the sum of the input amounts. The specified key does not need to be a valid Ristretto Public Key.

Claim hashes are defined as `Blake2b-256("\1" + inputs.length + inputs[0] + ... + inputs[n] + output)`, where the amount of inputs takes up 1 byte, every input takes up 33 bytes (the 32-byte hash and 1-byte output index), and the output key takes up 32 bytes.

signature must be the BLS signature produced by the Mints' designated claimee signing the hash.

`Claim` has a variable message length; the 1-byte amount of inputs, the inputs (each 33 bytes), the 32-byte output key, and the 48-byte BLS signature.

### Send

Send Transactions have the following additional field:

- signature: EdDSA signature.
- proof: Work that proves this isn't spam.

Every Send must have at least 1 input. Every Send input must be either a Claim or a Send, where the specified output is to the sender. If the outputs used as inputs are to different keys, the sender is the MuSig Public Key created from them, where `H` is Blake2b-512, `L` is `H(keys)` instead of `keys`, and `Hagg` is `H` with a prefixed domain separation tag of "agg".

Every output's key must be an Ristretto Public Key. The specified key does not need to be a valid Ristretto Public Key. The output's amount must be non-zero.

The amount sent in the transaction must be less than (2 ^ 64) - 1. The sum of the amount of every output must be equal to the sum of the amount of every input.

Send hashes are defined as `Blake2b-256("\2" + inputs.length + inputs[0] + ... + inputs[n] + outputs.length + outputs[0] + ... outputs[n])`, where the inputs length takes up 1 byte, every input takes up 33 bytes (the 32-byte hash and 1-byte output index), the outputs length takes up 1 byte, and every output takes up 40 bytes (the 32-byte key and 8-byte amount).

The signature must be the signature produced by the sender signing the hash.

The proof should cause the Send to beat the difficulty, as described in the Consensus and Difficulty documentation.

`Send` has a variable message length; the 1-byte amount of inputs, the inputs (each 33 bytes), 1-byte amount of outputs, the outputs (each 40 bytes), the 64-byte EdDSA signature, and the 4-byte proof.

### Data

Data Transactions have the following fields:

- data: The Data to store in the Transaction.
- signature: EdDSA Signature.
- proof: Work that proves this isn't spam.

Data Transactions are sequential. The first Data Transaction a sender creates has a zeroed out input. The data is their Ristretto Public Key. From then on, Data Transactions always have a single input; the hash of the previous Data Transaction created by that sender. Data Transactions' input's index and outputs are not used.

Data hashes are defined as `Blake2b-256("\3" + input.txHash + data)`, where input.txHash takes up 32 bytes and data is of a variable length.

The signature must be the signature produced by the sender signing the hash.

The data must be less than 256 bytes long (enforced by only providing a single byte to store the data length).

The proof should cause the Data to beat the difficulty, as described in the Consensus and Difficulty documentation.

`Data` has a variable message length; the 32-byte input, the 1-byte data length (where the length is the byte's value plus one), the variable-length data, the 64-byte EdDSA signature, and the 4-byte proof.
