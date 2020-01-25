include MainPersonal

proc mainNetwork() {.forceCheck: [].} =
    {.gcsafe.}:
        #Create the Network..
        network = newNetwork(
            params.NETWORK_ID,
            params.NETWORK_PROTOCOL,
            config.server,
            config.tcpPort,
            config.allowRepeatConnections,
            functions
        )

        #Start listening, if we're supposed to.
        if config.server:
            try:
                asyncCheck network.listen()
            except Exception:
                discard

        #Handle network events.
        #Connect to another node.
        functions.network.connect = proc (
            ip: string,
            port: int
        ) {.forceCheck: [
            ClientError
        ], async.} =
            try:
                await network.connect(ip, port)
            except ClientError as e:
                raise e
            except Exception as e:
                doAssert(false, "Couldn't connect to another node due to an Exception thrown by async: " & e.msg)

        #Get the peers we're connected to.
        functions.network.getPeers = proc (): seq[Client] {.inline, forceCheck: [].} =
            network.clients.clients

        #Broadcast a message.
        functions.network.broadcast = proc (
            msgType: MessageType,
            msg: string
        ) {.forceCheck: [].} =
            try:
                asyncCheck network.broadcast(
                    newMessage(
                        msgType,
                        msg
                    )
                )
            except Exception as e:
                doAssert(false, "Network.broadcast threw an Exception despite not naturally throwing any: " & e.msg)

        #Every minute, look for new peers if we don't have enough already.
        proc requestPeersRegularly() {.forceCheck: [], async.} =
            var peers: seq[tuple[ip: string, port: int]]
            try:
                peers = await network.requestPeers(params.SEEDS)
            except Exception as e:
                doAssert(false, "requestPeers threw an Exception despite not actually throwing any: " & e.msg)

            for peer in peers:
                try:
                    await network.connect(peer.ip, peer.port)
                except ClientError:
                    discard
                except Exception as e:
                    doAssert(false, "Couldn't connect to another node due to an Exception thrown by async: " & e.msg)

        try:
            addTimer(
                300000,
                false,
                proc (
                    fd: AsyncFD
                ): bool {.forceCheck: [].} =
                    try:
                        {.gcsafe.}:
                            asyncCheck requestPeersRegularly()
                    except Exception as e:
                        doAssert(false, "Couldn't request peers regularly due to an Exception thrown by async: " & e.msg)

            )
        except OSError as e:
            doAssert(false, "Couldn't set a timer due to an OSError: " & e.msg)
        except Exception as e:
            doAssert(false, "Couldn't set a timer due to an Exception: " & e.msg)

        #Also request peers now.
        try:
            asyncCheck requestPeersRegularly()
        except Exception as e:
            doAssert(false, "Couldn't request peers at the start of Meros: " & e.msg)
