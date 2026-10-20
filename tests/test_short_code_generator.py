
import pytest

from app.services.short_code_generator import (
    encode_base62,
    decode_base62,
)


@pytest.mark.parametrize(
    ("number", "expected_code"),
    [
        (0, "0"),
        (1, "1"),
        (61, "Z"),
        (62, "10"),
        (1000, "g8"),
        (1_000_000, "4c92"),
    ],
)
def test_encode_base62(number, expected_code):
    assert encode_base62(number) == expected_code


@pytest.mark.parametrize(
    ("code", "expected_number"),
    [
        ("0", 0),
        ("1", 1),
        ("Z", 61),
        ("10", 62),
        ("g8", 1000),
        ("4c92", 1_000_000),
    ],
)
def test_decode_base62(code, expected_number):
    assert decode_base62(code) == expected_number


@pytest.mark.parametrize(
    "number",
    [0, 1, 61, 62, 1000, 1_000_000, 10**15],
)
def test_encode_decode_round_trip(number):
    assert decode_base62(encode_base62(number)) == number


def test_encode_negative_number_raises_error():
    with pytest.raises(ValueError):
        encode_base62(-1)


def test_decode_invalid_character_raises_error():
    with pytest.raises(ValueError):
        decode_base62("abc@123")
