#Entry object.
import EntryObj

#Index object.
import IndexObj

#Finals lib.
import finals

#Receive object.
finalsd:
    type Receive* = ref object of Entry
        #Index.
        index* {.final.}: Index

#New Receive object.
func newReceiveObj*(
    index: Index
): Receive {.raises: [FinalAttributeError].} =
    result = Receive(
        index: index
    )
    result.ffinalizeIndex()

    result.descendant = EntryType.Receive
