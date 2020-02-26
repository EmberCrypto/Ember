#Serialize Difficulty Test.

#Test lib.
import unittest

#Fuzzing lib.
import ../../../../../Fuzzed

#Util lib.
import ../../../../../../src/lib/Util

#Hash lib.
import ../../../../../../src/lib/Hash

#Difficulty object.
import ../../../../../../src/Database/Merit/objects/DifficultyObj

#Serialize libs.
import ../../../../../../src/Database/Filesystem/DB/Serialize/Merit/SerializeDifficulty
import ../../../../../../src/Database/Filesystem/DB/Serialize/Merit/ParseDifficulty

#Compare Merit lib.
import ../../../../Merit/CompareMerit

#Random standard lib.
import random

suite "SerializeDifficulty":
    lowFuzzTest "Serialize and parse.":
        var
            #Difficulty value.
            value: string
            #Difficulty.
            difficulty: Difficulty
            #Reloaded Difficulty.
            reloaded: Difficulty

        #Randomize the value.
        value = ""
        for _ in 0 ..< 32:
            value &= char(rand(255))

        #Create the Difficulty.
        difficulty = newDifficultyObj(
            rand(high(int32)),
            rand(high(int32)),
            value.toHash(256)
        )

        #Serialize it and parse it back.
        reloaded = difficulty.serialize().parseDifficulty()

        #Test the serialized versions.
        check(difficulty.serialize() == reloaded.serialize())

        #Compare the Difficulty.
        compare(difficulty, reloaded)
