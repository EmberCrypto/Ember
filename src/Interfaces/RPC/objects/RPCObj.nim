import macros
import options
import tables
import json
export tables, json

import chronos

import ../../../lib/Errors

import ../../../Wallet/MinerWallet
import ../../../Wallet/Address

type
  RPCReplyFunction* = proc (
    res: JSONNode
  ): Future[void] {.gcsafe.}

  RPCHandle* = proc (
    req: JSONNode,
    reply: RPCReplyFunction
  ): Future[void] {.gcsafe.}

  RPC* = ref object
    handle*: RPCHandle

    toRPC*: ptr Channel[JSONNode]
    toGUI*: ptr Channel[JSONNode]

    server*: StreamServer
    alive*: bool

  #Stub replaced with a string; used to signify to parse the string from hex.
  hex* = object

template retrieveFromJSON*[T](
  value: JSONNode,
  expectedType: typedesc[T]
#Auto as hex != string (and so on).
): auto =
  when expectedType is Option:
    some(retrieveFromJSON(value, type(T().get())))
  else:
    #NOP for raw JSONNode.
    when expectedType is JSONNode:
      value
    elif expectedType is SomeInteger:
      if value.kind != JInt:
        #This function uses ParamError + message, an oddity, as ParamError has a hardcoded error message.
        #While that still applies to the actual RPC, this improves logging.
        raise newLoggedException(ParamError, "retrieveFromJSON expected int.")
      let num: int = value.getInt()
      if (num < int(low(T))) or (num > int(high(T))):
        raise newLoggedException(ParamError, "retrieveFromJSON expected an int within a specific range.")
      T(num)

    elif expectedType is string:
      if value.kind != JString:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a string.")
      value.getStr()

    elif expectedType is hex:
      var res: string
      try:
        res = retrieveFromJSON(value, string).parseHexStr()
      except ValueError:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a hex string.")
      res

    elif expectedType is Hash[256]:
      var res: string = retrieveFromJSON(value, hex)
      if res.len != 32:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a 32-byte hex string (64 chars).")
      res.toHash[:256]()

    elif expectedType is BLSPublicKey:
      var resStr: string = retrieveFromJSON(value, hex)
      if resStr.len != 192:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a 96-byte hex string (192 chars).")

      var res: BLSPublicKey
      try:
        res = newBLSPublicKey(resStr)
      except BLSError as e:
        raise newJSONRPCError(ValueError, "Invalid BLS Public Key: " & e.msg)
      res

    elif expectedType is Address:
      var res: Address
      try:
        res = retrieveFromJSON(value, string).getEncodedData()
      except ValueError as e:
        raise newLoggedException(ParamError, "retrieveFromJSON expected a string that is a valid address: " & e.msg)
      res

    else:
      {.error: "Trying to get an unknown type from JSON.".}

macro newRPCHandle*(
  routes: untyped
): untyped =
  #The generated function is a RPCHandle.
  #It needs to embody the functions passed in (routes), and also have a switch statement.
  #Said switch must format the parameters for the target function.
  #It finally needs to handle the reply logic.

  var
    body: NimNode = newStmtList(
      newEmptyNode(),
      #Default result of true.
      newVarStmt(ident("MACRO_res"), newCall(ident("%"), newLit(true)))
    )
    switch: NimNode = newNimNode(nnkCaseStmt).add(
      quote do:
        getStr(MACRO_rawReq["method"])
    )

  for route in routes:
    switch.add(newNimNode(nnkOfBranch))

    var
      argHandling: NimNode = newStmtList()
      routeCall: NimNode = newCall(route[0])
    for argument in route[3][1 ..< route[3].len]:
      var internalName: NimNode = ident("MACRO_ARGUMENT_" & argument[0].strVal)

      #If this is an option, and it's not present, we supply a value.
      #Else, we fail.
      var optionOrFail: NimNode
      if (argument[1].kind == nnkBracketExpr) and (argument[1][0].strVal == "Option"):
        optionOrFail = newAssignment(internalName, argument[2])
      else:
        optionOrFail = quote do:
          raise newLoggedException(ParamError, "")

      let
        argumentName: string = argument[0].strVal
        argumentType: NimNode = argument[1]
      var argumentActualType: NimNode = argumentType
      #Doesn't support Option[hex], something currently unused and unsupported elsewhere as well.
      if (argumentType.kind == nnkIdent) and (argumentType.strVal == "hex"):
        argumentActualType = ident("string")

      argHandling.add(
        quote do:
          var `internalName`: `argumentActualType`
          #Doesn't use a DotExpr for a more minimal AST.
          if hasKey(MACRO_rawReq["params"], `argumentName`):
            `internalName` = retrieveFromJSON(MACRO_rawReq["params"][`argumentName`], `argumentType`)
          else:
            `optionOrFail`
      )

      #Make sure it's passed to the function.
      routeCall.add(internalName)

    var hasAsyncPragma: bool = false
    for pragma in route[4]:
      if (pragma.kind == nnkIdent) and (pragma.strVal == "async"):
        hasAsyncPragma = true

    var returnType: NimNode = route[3][0]
    if hasAsyncPragma:
      if returnType.kind == nnkBracketExpr:
        returnType = returnType[0]
      #If this is async, add an await.
      routeCall = quote do:
        await `routeCall`

    #If it's not void, set MACRO_res.
    if (
      (returnType.kind != nnkEmpty) or
      (
        (returnType.kind == nnkIdent) and
        (returnType.strVal != "void")
      )
    ):
      routeCall = quote do:
        MACRO_res = %(`routeCall`)

    let caseBody: NimNode = argHandling
    caseBody.add(routeCall)
    switch[^1].add(newStrLitNode(route[0].strVal), caseBody)

  switch.add(newNimNode(nnkElse))
  switch[^1].add(
    quote do:
      raise newJSONRPCError(-32601, "Method not found")
  )

  body[0] = routes
  # Replace instances of hex/remove default argument values
  # First is solely used as a tag, latter is since they shouldn't be needed
  for r in 0 ..< body[0].len:
    for i in 1 ..< body[0][r][3].len:
      #Doesn't support Option[hex] which we don't use.
      if (body[0][r][3][i][1].kind == nnkIdent) and (body[0][r][3][i][1].strVal == "hex"):
        body[0][r][3][i][1] = ident("string")
      body[0][r][3][i][2] = newNimNode(nnkEmpty)
  body.add(switch)

  #Call reply.
  body.add(
    quote do:
      await MACRO_reply(MACRO_res)
  )

  result = newProc(
    newEmptyNode(),
    @[
      newNimNode(nnkBracketExpr).add(
        ident("Future"),
        ident("void")
      ),
      newIdentDefs(ident("MACRO_rawReq"), ident("JSONNode")),
      newIdentDefs(ident("MACRO_reply"), ident("RPCReplyFunction"))
    ],
    body,
    nnkLambda,
    quote do:
      {.closure, async, gcsafe.}
  )
