from typing import Dict, List, Any
from os import remove
from time import sleep
import json
import socket

from e2e.Meros.Meros import Meros

from e2e.Tests.Errors import NodeError, TestError

class RPC:
  def __init__(
    self,
    meros: Meros,
    timeout: float = 0
  ) -> None:
    self.meros: Meros = meros
    self._timeout: float = timeout
    self.socket: socket.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self._connect(self._timeout)

  def _connect(self, timeout):
    while True:
      try:
        self.socket.connect(("127.0.0.1", self.meros.rpc))
        break
      except ConnectionRefusedError:
        timeout -= 1
        if timeout <= 0:
          raise TimeoutError()
        sleep(1)

  def call(
    self,
    module: str,
    method: str,
    args: List[Any] = []
  ) -> Any:
    try:
      self.socket.send(
        bytes(
          json.dumps(
            {
              "jsonrpc": "2.0",
              "id": 0,
              "method": module + "_" + method,
              "params": args
            }
          ),
          "utf-8"
        )
      )
    except BrokenPipeError:
      raise NodeError()

    response: bytes = bytes()
    nextChar: bytes = bytes()
    counter: int = 0
    while True:
      try:
        nextChar = self.socket.recv(1)
      except Exception:
        raise NodeError()
      if not nextChar:
        raise NodeError()
      response += nextChar

      if response[-1] == response[0]:
        counter += 1
      elif (chr(response[-1]) == ']') and (chr(response[0]) == '['):
        counter -= 1
      elif (chr(response[-1]) == '}') and (chr(response[0]) == '{'):
        counter -= 1
      if counter == 0:
        break

    #Raise an exception on error.
    result: Dict[str, Any] = json.loads(response)
    if "error" in result:
      raise TestError(result["error"]["message"] + ".")
    return result["result"]

  def quit(
    self
  ) -> None:
    self.call("system", "quit")
    self.meros.calledQuit = True

  #Reset the Meros node, deleting its Database and rebooting it.
  #Used after calling a Liver and before calling a Syncer.
  def reset(
    self
  ) -> None:
    self.quit()
    sleep(3)

    remove("./data/e2e/devnet-" + self.meros.db)
    remove("./data/e2e/devnet-" + self.meros.db + "-lock")

    self.meros = Meros(self.meros.db, self.meros.tcp, self.meros.rpc)
    sleep(5)

    self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    self._connect(self._timeout)
