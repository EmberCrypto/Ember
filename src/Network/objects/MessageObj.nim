#Util.
import ../../lib/Util

#finals lib.
import finals

finalsd:
    type
        #Message Type enum.
        MessageType* = enum
            Handshake = 0,
            Syncing = 1,
            BlockRequest = 2,
            EntryRequest = 3
            DataMissing = 4,
            SyncingOver = 5,
            HandshakeOver = 6,
            Verification = 7,
            Block = 8,
            Claim = 9,
            Send = 10,
            Receive = 11,
            Data = 12

        #Message object.
        Message* = ref object of RootObj
            client* {.final.}: uint
            content* {.final.}: MessageType
            len* {.final.}: uint
            header* {.final.}: string
            message* {.final.}: string

#Finalize the Message.
func finalize(
    msg: Message
) {.raises: [].} =
    msg.ffinalizeClient()
    msg.ffinalizeContent()
    msg.ffinalizeLen()
    msg.ffinalizeHeader()
    msg.ffinalizeMessage()

#Constructor for incoming data.
func newMessage*(
    client: uint,
    content: MessageType,
    len: uint,
    header: string,
    message: string
): Message {.raises: [].} =
    result = Message(
        client: client,
        content: content,
        len: len,
        header: header,
        message: message
    )
    result.finalize()

#Constructor for outgoing data.
func newMessage*(
    content: MessageType,
    message: string
): Message {.raises: [].} =
    #Serialize the length.
    var
        len: int = message.len
        length: string = ""
    while len > 255:
        len = len mod 255
        length &= char(255)
    length &= char(len)

    #Create the Message.
    result = Message(
        content: content,
        len: uint(message.len),
        header: char(content) & length,
        message: message
    )
    result.finalize()

#Stringify.
func `$`*(msg: Message): string {.raises: [].} =
    msg.header & msg.message
