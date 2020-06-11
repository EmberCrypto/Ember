from typing import Dict, List, Tuple, Set, Any

import re

from pylint.lint import PyLinter
from pylint.checkers import BaseChecker
from pylint.interfaces import IRawChecker

quotations: Set[str] = {'"', '\''}
startChars: Set[str] = {'(', '[', '{'}
endChars: Set[str] = {')', ']', '}'}

#Conjunctions used to combine values.
#If a line ends in these, it's an infix multiline expression.
#We don't check for those.
conjunctions: Set[str] = {'+', '-', '*', '/', "and", "or"}

#Checks if a line ends in a conjunction.
def endsInConjunction(
  line: str
) -> bool:
  for conjunction in conjunctions:
    if line[-len(conjunction):] == conjunction:
      return True
  return False

#Checks if an object ends on the same line.
def endsOnLine(
  line: str,
  num: int,
) -> bool:
  count: int = 1
  inStr: str = ""
  for curr in range(num + 1, len(line)):
    if line[curr] in quotations:
      if inStr == "":
        inStr = line[curr]
      elif (line[curr] == inStr) and (line[curr - 1] != '\\'):
        inStr = ""
      elif (line[curr] == inStr) and (curr >= 2) and (line[curr - 2] == '\\'):
        inStr = ""

    if not inStr:
      if line[curr] in startChars:
        count += 1
      elif line[curr] in endChars:
        count -= 1

    if count == 0:
      return True
  return False

#Check if an object contains an expanded object, yet is not expanded itself.
def nested(
  lines: List[Tuple[int, str]],
  num: int,
  pos: int
) -> bool:
  line: str = lines[num][1]
  if pos == len(line) - 1:
    return False

  #Matching ending symbols.
  endSyms: str = ""

  #Generate the expected end symbols for this line.
  for c in range(pos, len(line)):
    if line[c] == '(':
      endSyms += ')'
    elif line[c] == '[':
      endSyms += ']'
    elif line[c] == '{':
      endSyms += '}'

  #If there isn't at least one other object, return false.
  if len(endSyms) < 2:
    return False

  #Find out how many values there are.
  values: int = 1
  for num2 in range(num + 1, len(lines)):
    line = lines[num2][1]
    if line[-1] == ',':
      values += 1
      continue

    values += 1
    break

  #Make sure the ending symbols line up.
  endSyms = endSyms[::-1]
  if lines[num + values][1][-1] == ',':
    endSyms += ','
  try:
    if lines[num + values][1] != endSyms:
      return False
  except Exception:
    return False

  #If we made it through that, return true.
  return True

#Check if an expression contains a curly bracket expression with a multiline expansion.
def containsExpandedCurlies(
  lines: List[Tuple[int, str]],
  numArg: int,
  currArg: int
) -> bool:
  num: int = numArg
  curr: int = currArg + 1
  levels: int = 1
  #Run until the object is closed.
  while levels != 0:
    if curr == len(lines[num][1]):
      curr = 0
      num += 1
      while lines[num][1] == "":
        num += 1

    #Track levels.
    if lines[num][1][curr] in startChars:
      levels += 1
    elif lines[num][1][curr] in endChars:
      levels -= 1

    #If this is an opening curly bracket, and this is at the end of a line, it's a multiline curly bracket expansion.
    if (lines[num][1][curr] == '{') and (curr + 1 == len(lines[num][1])):
      return True

    #Update curr.
    curr += 1

  #If we completed the expression without returning true, return false.
  return False

#Check a multiline object was expanded properly.
def checkMultilineExpansion(
  lines: List[Tuple[int, str]],
  num: int
) -> bool:
  #Used is the line number a child expanded object ends on.
  used: int = num + 1

  #Iterate over the next lines.
  for num2 in range(num + 1, len(lines)):
    #If this line was used by a child object, continue.
    if num2 < used:
      continue
    #Update used to the current line.
    used = num2

    #Extract the line.
    line: str = lines[num2][1]
    if line == "":
      continue
    #Set the count to 0.
    #We'd set it to 1 if we wanted the end of the object.
    #We want the end of the value.
    count: int = 0
    #Current character of our current line.
    curr: int = -1
    inStr: str = ""
    while curr < len(line) - 1:
      curr += 1

      if line[curr] in quotations:
        if inStr == "":
          inStr = line[curr]
        elif (line[curr] == inStr) and (line[curr - 1] != '\\'):
          inStr = ""
        elif (line[curr] == inStr) and (curr >= 2) and (line[curr - 2] == '\\'):
          inStr = ""

      if inStr:
        continue

      if not inStr:
        #If the character is a starting char, increment.
        if line[curr] in startChars:
          count += 1
        #Else, if it's an ending char, decrement.
        elif line[curr] in endChars:
          count -= 1

      #Handle expanded child arguments/conjunctions.
      if ((count > 0) or endsInConjunction(line)) and (curr + 1 == len(line)):
        used += 1
        while lines[used][1] == "":
          used += 1
        line += lines[used][1]
        continue

      #If we've balanced out...
      if count == 0:
        #This is the end of a value, theoretically.
        #It'll have:
        # - A period if it's chained.
        # - A space if it's a ternary.
        # - A comma if it's succeeded.
        # - Nothing if it's the last value.

        #Handle the last value.
        if curr + 1 == len(line):
          if lines[used + 1][1][0] in endChars:
            return True

        #If it's a comma, make sure it's the end of the line.
        if line[curr + 1] == ',':
          if curr + 1 != len(line) - 1:
            return False
          break

        #Since it's not a comma, keep going.

      #If we ended the object, return.
      if count == -1:
        if curr != 0:
          return False
        return True

  #We can never reach this point. The program terminates on closure.
  #A dangling symbol will cause an error. That said, type checkers insist we return SOMETHING.
  return False

#Get the length of a multiline expansion, if compressed to a single line.
#Does not include the opening symbol.
def getMultilineExpansionlength(
  lines: List[Tuple[int, str]],
  num: int
) -> int:
  #Set the count to 1.
  count: int = 1
  #The result is initially set to -1.
  #If we increment 1 per line (space), and 1 per char, we get ( ).
  #Since we also add the final line, we don't want to track the ).
  result: int = -2
  for num2 in range(num + 1, len(lines)):
    result += 1
    line: str = lines[num2][1]
    inStr: str = ""
    for c in range(len(line)):
      result += 1
      if line[c] in quotations:
        if inStr == "":
          inStr = line[c]
        elif (line[c] == inStr) and (line[c - 1] != '\\'):
          inStr = ""
        elif (line[c] == inStr) and (c >= 2) and (line[c - 2] == '\\'):
          inStr = ""

      if not inStr:
        if line[c] in startChars:
          count += 1
        elif line[c] in endChars:
          count -= 1

      if count == 0:
        result += len(line)
        return result

  return 0

#MyPy is failing to ID this, even with the stub files.
class MultilineExpansionChecker(
  BaseChecker  #type: ignore
):
  __implements__: Any = IRawChecker
  name: str = "multiline-expansion"
  msgs: Dict[str, Tuple[str, str, str]] = {
    "R5131": (
      "Place each class definition's parents on their own line and omit () when there's no parents.",
      "improper-class-multiline-definition",
      "Used when a class definition does not have its parents each on their own line or includes () despite not having parents."
    ),

    "R5132": (
      "Place each function definition's arguments on their own line.",
      "improper-function-multiline-definition",
      "Used when a function definition does not have its arguments each on their own line."
    ),

    "R5133": (
      "Place each element in a multiline-expansion on their own line.",
      "improper-multiline-expansion",
      "Used when code, noted by ()/[]/{}, which is over the line length, was split into lines where comma-delimited elements shared a line."
    ),

    "R5134": (
      "Don't perform a multiline-expansion where not necessary.",
      "unneeded-multiline-expansion",
      "Used when code, noted by ()/[], which is not over the line length, was split into multiple lines."
    )
  }

  def __init__(
    self,
    linter: PyLinter
  ) -> None:
    BaseChecker.__init__(self, linter)

  #Check a class definition had its parents written properly.
  def checkClass(
    self,
    lines: List[Tuple[int, str]],
    num: int
  ) -> None:
    #Extract the line.
    line: str = lines[num][1]

    #Check if the class has no parents.
    if re.match(r"class +\w*\:", line) is not None:
      return

    #If it does have arguments, make sure the function doesn't place any argument on the first line.
    if (line.count('(') != 1) or (line[-1] != '('):
      self.add_message("improper-class-multiline-definition", line=num+1)
      return

    #Check every argument is on their own line.
    if not checkMultilineExpansion(lines, num):
      self.add_message("improper-class-multiline-definition", line=num+1)

  #Check a function definition had its arguments written properly.
  def checkFunction(
    self,
    lines: List[Tuple[int, str]],
    num: int
  ) -> None:
    #Extract the line.
    line: str = lines[num][1]

    #Check if the function has no arguments.
    if re.match(r"def +\w*\(\)", line) is not None:
      return

    #If it does have arguments, make sure the function doesn't place any argument on the first line.
    if (line.count('(') != 1) or (line[-1] != '('):
      self.add_message("improper-function-multiline-definition", line=num+1)
      return

    #Check every argument is on their own line.
    if not checkMultilineExpansion(lines, num):
      self.add_message("improper-function-multiline-definition", line=num+1)

  def process_line(
    self,
    lines: List[Tuple[int, str]],
    num: int
  ) -> None:
    #Extract the line.
    line: str = lines[num][1]

    #Check if the line starts with a class def.
    if (len(line) > 5) and (line[0 : 5] == "class"):
      self.checkClass(lines, num)
      return

    #Check if the line starts with a function def.
    if (len(line) > 3) and (line[0 : 3] == "def"):
      self.checkFunction(lines, num)
      return

    #Check for ()/[] values.
    inStr: str = ""
    skipToEnd: bool = False
    for curr in range(len(line)):
      if skipToEnd and (curr != len(line) - 1):
        continue

      if line[curr] in quotations:
        if inStr == "":
          inStr = line[curr]
        elif (line[curr] == inStr) and (line[curr - 1] != '\\'):
          inStr = ""
        elif (line[curr] == inStr) and (curr >= 2) and (line[curr - 2] == '\\'):
          inStr = ""
      elif (line[curr] in startChars) and (not inStr):
        #If it ends on this line, continue.
        if endsOnLine(line, curr):
          continue

        #If this object only has one value, which is expanded, yet isn't itself, skip to said object.
        isNested: int = nested(lines, num, curr)
        if isNested:
          skipToEnd = True
          continue

        #Check the object should've been expanded and was properly.
        #Make sure the multiline object doesn't have values on the same line.
        if curr + 1 != len(line):
          self.add_message("improper-multiline-expansion", line=num+1)
          return

        #Make sure each value has their own line.
        if not checkMultilineExpansion(lines, num):
          self.add_message("improper-multiline-expansion", line=num+1)
          return

        #Make sure it should've been expanded.
        #Allow curly brackets to always be expanded and objects to be expanded if they contain expanded curly brackets.
        if (line[curr] != '{') and (not containsExpandedCurlies(lines, num, curr)):
          if lines[num][0] + curr + getMultilineExpansionlength(lines, num) < 80:
            self.add_message("unneeded-multiline-expansion", line=num+1)
            return

  def process_module(
    self,
    module: Any
  ) -> None:
    lines: List[Tuple[int, str]] = []
    for (_, lineBytes) in enumerate(module.stream()):
      #Convert from bytes.
      lineDecoded: str = lineBytes.decode("utf-8")
      #Remove whitespace.
      line: str = lineDecoded.strip()

      if line:
        #Remove comments.
        if line[0] == '#':
          line = ""

        inStr: str = ""
        for c in range(len(line)):
          if line[c] in quotations:
            if inStr == "":
              inStr = line[c]
            elif (line[c] == inStr) and (line[c - 1] != '\\'):
              inStr = ""
            elif (line[c] == inStr) and (c >= 2) and (line[c - 2] == '\\'):
              inStr = ""
          elif (line[c] == '#') and (not inStr):
            line = line[0 : c].rstrip()
            break

      #Add the line.
      lines.append((len(lineDecoded) - len(lineDecoded.lstrip()), line))

    for num in range(len(lines)):
      self.process_line(lines, num)

def register(
  linter: PyLinter
) -> None:
  linter.register_checker(MultilineExpansionChecker(linter))
