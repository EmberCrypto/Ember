from typing import Any
from abc import ABC, abstractmethod, abstractproperty

class FieldElement(
  ABC
):
  @abstractmethod
  def __init__(
    self,
    #List[int] or int. The BLS impl shipped in this codebase also accepts itself.
    #Just a nice convenience function to cleanly make sure args are viable.
    value: Any
  ) -> None:
    ...

  #Other should be another FieldElement or a value passable to init.
  @abstractmethod
  def __add__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def __sub__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def __mul__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def div(
    self,
    other: Any,
    q: Any
  ) -> Any:
    ...

  @abstractmethod
  def __pow__(
    self,
    exp: int
  ) -> Any:
    ...

  @abstractmethod
  def __eq__(
    self,
    other: Any
  ) -> bool:
    ...

  @abstractmethod
  def __ne__(
    self,
    other: Any
  ) -> bool:
    ...

  #Positive/negative (0/1); not the signature scheme operation.
  @abstractmethod
  def sign(
    self
  ) -> int:
    ...

  @abstractmethod
  def negative(
    self
  ) -> Any:
    ...

  @abstractmethod
  def sqrt(
    self
  ) -> Any:
    ...

class GroupElement(
  ABC
):
  @abstractmethod
  def __init__(
    self,
    x: FieldElement,
    y: FieldElement
  ) -> Any:
    ...

  @abstractmethod
  def __add__(
    self,
    other: Any
  ) -> Any:
    ...

  @abstractmethod
  def clearCofactor(
    self
  ) -> Any:
    ...

  @abstractproperty
  def x(
    self
  ) -> str:
    ...

  @abstractproperty
  def y(
    self
  ) -> str:
    ...
