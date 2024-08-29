"""A program for Trang."""

from pathlib import Path


def add(a: int, b: int) -> int:
  """Add two numbers."""
  return a + b


def main() -> None:
  """Find out where you are."""
  print("Hello, World!")
  print(Path.cwd())
  print(add(1, 2))


if __name__ == "__main__":
  main()
