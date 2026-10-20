ALPHABET = (
    "0123456789"
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
)

BASE = len(ALPHABET)

def encode_base62(number:int)->str:
    if number<0:
        raise ValueError("Number should be non-negative")
    if number ==0:
        return ALPHABET[0]
    result = []
    while number>0:
        number,remainder = divmod(number,BASE)
        result.append(ALPHABET[remainder])
    return "".join(reversed(result))

def decode_base62(code:str)->int:
    number = 0
    for char in code:
        digit = ALPHABET.find(char)
        if digit == -1:
            raise ValueError(f"Invalid Base62 Character: {char}")
        number = number*BASE+digit
    return number

    