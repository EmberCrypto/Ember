#Types.
from typing import Callable, List

#Exceptions.
from PythonTests.Tests.Errors import EmptyError, NodeError, TestError, SuccessError

#Meros classes.
from PythonTests.Meros.Meros import Meros
from PythonTests.Meros.RPC import RPC

#Tests.
from PythonTests.Tests.Merit.ChainAdvancementTest import ChainAdvancementTest
from PythonTests.Tests.Merit.DifficultyTest import DifficultyTest
from PythonTests.Tests.Merit.StateTest import StateTest
from PythonTests.Tests.Merit.HundredTwentyFourTest import HundredTwentyFourTest
from PythonTests.Tests.Merit.Reorganizations.DepthOneTest import DepthOneTest
from PythonTests.Tests.Merit.Reorganizations.LongerChainMoreWorkTest import LongerChainMoreWorkTest
from PythonTests.Tests.Merit.Reorganizations.ShorterChainMoreWorkTest import ShorterChainMoreWorkTest
from PythonTests.Tests.Merit.Reorganizations.DelayedMeritHolderTest import DelayedMeritHolderTest

from PythonTests.Tests.Merit.Templates.EightyEightTest import EightyEightTest
from PythonTests.Tests.Merit.Templates.TElementTest import TElementTest

from PythonTests.Tests.Transactions.DataTest import DataTest
from PythonTests.Tests.Transactions.AggregatedClaimTest import AggregatedClaimTest
from PythonTests.Tests.Transactions.SameInputTest import SameInputTest
from PythonTests.Tests.Transactions.CompetingFinalizedTest import CompetingFinalizedTest
from PythonTests.Tests.Transactions.FiftyTest import FiftyTest
from PythonTests.Tests.Transactions.PruneUnaddableTest import PruneUnaddableTest
from PythonTests.Tests.Transactions.HundredFortySevenTest import HundredFortySevenTest

from PythonTests.Tests.Consensus.Verification.ParsableTest import VParsableTest
from PythonTests.Tests.Consensus.Verification.UnknownTest import VUnknownTest
from PythonTests.Tests.Consensus.Verification.CompetingTest import VCompetingTest
from PythonTests.Tests.Consensus.Verification.HundredTwoTest import HundredTwoTest
from PythonTests.Tests.Consensus.Verification.HundredFortyTwoTest import HundredFortyTwoTest
from PythonTests.Tests.Consensus.Verification.HundredFiftyFiveTest import HundredFiftyFiveTest

from PythonTests.Tests.Consensus.Difficulties.SendDifficultyTest import SendDifficultyTest
from PythonTests.Tests.Consensus.Difficulties.DataDifficultyTest import DataDifficultyTest

from PythonTests.Tests.Consensus.MeritRemoval.SameNonceTest import SameNonceTest
from PythonTests.Tests.Consensus.MeritRemoval.VerifyCompetingTest import VerifyCompetingTest
from PythonTests.Tests.Consensus.MeritRemoval.InvalidCompetingTest import InvalidCompetingTest
from PythonTests.Tests.Consensus.MeritRemoval.PartialTest import PartialTest
from PythonTests.Tests.Consensus.MeritRemoval.MultipleTest import MultipleTest
from PythonTests.Tests.Consensus.MeritRemoval.PendingActionsTest import PendingActionsTest
from PythonTests.Tests.Consensus.MeritRemoval.RepeatTest import RepeatTest
from PythonTests.Tests.Consensus.MeritRemoval.SameElementTest import SameElementTest

from PythonTests.Tests.Consensus.MeritRemoval.HundredTwentyThree.HTTPartialTest import HTTPartialTest
from PythonTests.Tests.Consensus.MeritRemoval.HundredTwentyThree.HTTSwapTest import HTTSwapTest
from PythonTests.Tests.Consensus.MeritRemoval.HundredTwentyThree.HTTPacketTest import HTTPacketTest

from PythonTests.Tests.Consensus.MeritRemoval.HundredThirtyThreeTest import HundredThirtyThreeTest
from PythonTests.Tests.Consensus.MeritRemoval.HundredThirtyFiveTest import HundredThirtyFiveTest

from PythonTests.Tests.Consensus.HundredSix.HundredSixSignedElementsTest import HundredSixSignedElementsTest
from PythonTests.Tests.Consensus.HundredSix.HundredSixBlockElementsTest import HundredSixBlockElementsTest
from PythonTests.Tests.Consensus.HundredSix.HundredSixMeritRemovalsTest import HundredSixMeritRemovalsTest

from PythonTests.Tests.Network.PeersTest import PeersTest
from PythonTests.Tests.Network.HundredTwentyFiveTest import HundredTwentyFiveTest

#Arguments.
from sys import argv

#Sleep standard function.
from time import sleep

#ShUtil standard lib.
import shutil

#Format Exception standard function.
from traceback import format_exc

#Initial port.
port: int = 5132

#Results.
ress: List[str] = []

#Tests.
tests: List[Callable[[RPC], None]] = [
    ChainAdvancementTest,
    DifficultyTest,
    StateTest,
    HundredTwentyFourTest,
    DepthOneTest,
    LongerChainMoreWorkTest,
    ShorterChainMoreWorkTest,
    DelayedMeritHolderTest,

    EightyEightTest,
    TElementTest,

    DataTest,
    AggregatedClaimTest,
    SameInputTest,
    CompetingFinalizedTest,
    FiftyTest,
    PruneUnaddableTest,
    HundredFortySevenTest,

    VParsableTest,
    VUnknownTest,
    VCompetingTest,
    HundredTwoTest,
    HundredFortyTwoTest,
    HundredFiftyFiveTest,

    SendDifficultyTest,
    DataDifficultyTest,

    SameNonceTest,
    VerifyCompetingTest,
    InvalidCompetingTest,
    PartialTest,
    MultipleTest,
    PendingActionsTest,
    RepeatTest,
    SameElementTest,

    HTTPartialTest,
    HTTSwapTest,
    HTTPacketTest,

    HundredThirtyThreeTest,
    HundredThirtyFiveTest,

    HundredSixSignedElementsTest,
    HundredSixBlockElementsTest,
    HundredSixMeritRemovalsTest,

    PeersTest,
    HundredTwentyFiveTest
]

#Tests to run.
#If any were specified over the CLI, only run those.
testsToRun: List[str] = argv[1:]
#Else, run all.
if not testsToRun:
    for test in tests:
        testsToRun.append(test.__name__)

#Remove invalid tests.
for t in range(len(testsToRun)):
    found: bool = False
    for test in tests:
        #Enable specifying tests over the CLI without the "Test" suffix.
        if (test.__name__ == testsToRun[t]) or (test.__name__ == testsToRun[t] + "Test"):
            if testsToRun[t][-4:] != "Test":
                testsToRun[t] += "Test"

            found = True
            break

    if not found:
        ress.append("\033[0;31mCouldn't find " + testsToRun[t] + ".")

#Delete the PythonTests data directory.
try:
    shutil.rmtree("./data/PythonTests")
except FileNotFoundError:
    pass

#Run every test.
for test in tests:
    if not testsToRun:
        break
    if test.__name__ not in testsToRun:
        continue
    testsToRun.remove(test.__name__)

    print("\033[0;37mRunning " + test.__name__ + ".")

    #Message to display on a Node crash.
    crash: str = "\033[5;31m" + test.__name__ + " caused the node to crash!\033[0;31m"

    #Meros instance.
    meros: Meros = Meros(test.__name__, port, port + 1)
    sleep(5)

    rpc: RPC = RPC(meros)
    try:
        test(rpc)
        raise SuccessError()
    except SuccessError as e:
        ress.append("\033[0;32m" + test.__name__ + " succeeded.")
    except EmptyError as e:
        ress.append("\033[0;33m" + test.__name__ + " is empty.")
    except NodeError as e:
        ress.append(crash)
    except TestError as e:
        ress.append("\033[0;31m" + test.__name__ + " failed: " + str(e))
    except Exception as e:
        ress.append("\033[0;31m" + test.__name__ + " is invalid.")
        ress.append(format_exc().rstrip())
    finally:
        try:
            rpc.quit()
            meros.quit()
        except NodeError:
            if ress[-1] != crash:
                ress.append(crash)

        print("\033[0;37m" + ("-" * shutil.get_terminal_size().columns))

for res in ress:
    print(res)
print("\033[0;37m", end="")
