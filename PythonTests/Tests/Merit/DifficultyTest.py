#Types.
from typing import Dict, List, IO, Any

#Blockchain class.
from PythonTests.Classes.Merit.Blockchain import Blockchain

#TestError Exception.
from PythonTests.Tests.Errors import TestError

#Meros classes.
from PythonTests.Meros.RPC import RPC
from PythonTests.Meros.Liver import Liver

#JSON standard lib.
import json

def DifficultyTest(
    rpc: RPC
) -> None:
    #Blocks.
    file: IO[Any] = open("PythonTests/Vectors/Merit/BlankBlocks.json", "r")
    blocks: List[Dict[str, Any]] = json.loads(file.read())
    file.close()

    #Blockchain.
    blockchain: Blockchain = Blockchain.fromJSON(blocks)

    def checkDifficulty(
        block: int
    ) -> None:
        if int(rpc.call("merit", "getDifficulty")) != blockchain.difficulties[block]:
            raise TestError("Difficulty doesn't match.")

    Liver(rpc, blocks, everyBlock=checkDifficulty).live()
