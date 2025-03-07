import pytest

from vyper import compiler
from vyper.exceptions import InvalidOperation, StructureException, SyntaxException, TypeMismatch

fail_list = [
    (
        """
@external
def baa():
    x: Bytes[50] = b""
    y: Bytes[50] = b""
    z: Bytes[50] = x + y
    """,
        InvalidOperation,
    ),
    """
@external
def baa():
    x: Bytes[50] = b""
    y: int128 = 0
    y = x
    """,
    """
@external
def baa():
    x: Bytes[50] = b""
    y: int128 = 0
    x = y
    """,
    """
@external
def baa():
    x: Bytes[50] = b""
    y: Bytes[60] = b""
    x = y
    """,
    """
@external
def foo(x: Bytes[100]) -> Bytes[75]:
    return x
    """,
    """
@external
def foo(x: Bytes[100]) -> int128:
    return x
    """,
    """
@external
def foo(x: int128) -> Bytes[75]:
    return x
    """,
    (
        """
@external
def foo() -> Bytes[10]:
    x: Bytes[10] = '0x1234567890123456789012345678901234567890'
    x = 0x1234567890123456789012345678901234567890
    return x
    """,
        TypeMismatch,
    ),
    (
        """
@external
def foo() -> Bytes[10]:
    return "badmintonzz"
    """,
        TypeMismatch,
    ),
    (
        """
@external
def test() -> Bytes[1]:
    a: Bytes[1] = 0b0000001  # needs multiple of 8 bits.
    return a
    """,
        SyntaxException,
    ),
    (
        """
@external
def test() -> Bytes[2]:
    a: Bytes[2] = x"abc"  # non-hex nibbles
    return a
    """,
        SyntaxException,
    ),
    (
        """
@external
def test() -> Bytes[10]:
    # GH issue 4405 example 1
    a: Bytes[10] = x x x x x x"61"  # messed up hex prefix
    return a
    """,
        SyntaxException,
    ),
    (
        """
@external
def foo():
    a: Bytes = b"abc"
    """,
        StructureException,
    ),
]


@pytest.mark.parametrize("bad_code", fail_list)
def test_bytes_fail(bad_code):
    if isinstance(bad_code, tuple):
        with pytest.raises(bad_code[1]):
            compiler.compile_code(bad_code[0])
    else:
        with pytest.raises(TypeMismatch):
            compiler.compile_code(bad_code)


@pytest.mark.xfail
def test_hexbytes_offset():
    good_code = """
    event X:
    a: Bytes[2]

@deploy
def __init__():
    # GH issue 4405, example 1
    #
    # log changes offset of HexString, and the hex_string_locations tracked
    # location is incorrect when visiting ast
    log X(a = x"6161")
    """
    # move this to valid list once it passes.
    assert compiler.compile_code(good_code) is not None


valid_list = [
    """
@external
def foo(x: Bytes[100]) -> Bytes[100]:
    return x
    """,
    """
@external
def foo(x: Bytes[100]) -> Bytes[150]:
    return x
    """,
    """
@external
def baa():
    x: Bytes[50] = b""
    """,
]


@pytest.mark.parametrize("good_code", valid_list)
def test_bytes_success(good_code):
    assert compiler.compile_code(good_code) is not None
