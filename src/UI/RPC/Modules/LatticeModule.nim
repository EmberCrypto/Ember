#Numerical libs.
import BN
import ../../../lib/Base

#Wallet lib.
import ../../..//Wallet/Wallet

#Lattice lib.
import ../../../Database/Lattice/Lattice

#RPC object.
import ../objects/RPCObj

#EventEmitter lib.
import ec_events

#String utils standard lib.
import strutils

#JSON standard lib.
import json

#Create a Send Node.
proc send(rpc: RPC, address: string, amount: BN, nonce: BN) {.raises: [Exception].} =
    #Create the Send.
    var send: Send = newSend(
        address,
        amount,
        nonce
    )
    #Mine the Send.
    send.mine("aa".repeat(64).toBN(16))
    #Sign the Send.
    if not rpc.wallet.sign(send):
        raise newException(Exception, "Couldn't sign the send.")

    #Add it.
    rpc.events.get(
        proc (send: Send),
        "lattice.send"
    )(send)

#Create a Receive Node.
proc receive(rpc: RPC, address: string, inputNonce: BN, nonce: BN) {.raises: [Exception].} =
    #Create the Receive.
    var recv: Receive = newReceive(
        address,
        inputNonce,
        nonce
    )
    #Sign the Receive.
    rpc.wallet.sign(recv)

    #Add it.
    rpc.events.get(
        proc (recv: Receive),
        "lattice.receive"
    )(recv)

#Get the height of an account.
proc getHeight(rpc: RPC, account: string) {.raises: [ValueError, Exception].} =
    #Get the height.
    var height: BN = rpc.events.get(
        proc (account: string): BN,
        "lattice.getHeight"
    )(account)

    #Send back the height.
    rpc.toGUI[].send(%* {
        "height": $height
    })

#Get the balance of an account.
proc getBalance(rpc: RPC, account: string) {.raises: [ValueError, Exception].} =
    #Get the balance.
    var balance: BN = rpc.events.get(
        proc (account: string): BN,
        "lattice.getBalance"
    )(account)

    #Send back the balance.
    rpc.toGUI[].send(%* {
        "balance": $balance
    })

#Handler.
proc `latticeModule`*(rpc: RPC, json: JSONNode) {.raises: [ValueError, Exception].} =
    #Switch based off the method.
    case json["method"].getStr():
        of "send":
            rpc.send(
                json["args"][0].getStr(),
                newBN(json["args"][1].getStr()),
                newBN(json["args"][2].getStr())
            )

        of "receive":
            rpc.receive(
                json["args"][0].getStr(),
                newBN(json["args"][1].getStr()),
                newBN(json["args"][2].getStr())
            )
        of "getHeight":
            rpc.getHeight(
                json["args"][0].getStr()
            )

        of "getBalance":
            rpc.getBalance(
                json["args"][0].getStr()
            )
