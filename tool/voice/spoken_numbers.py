"""Numbers in words, so the voice never has to guess how to read digits."""

_IT_UNITS = ["zero", "uno", "due", "tre", "quattro", "cinque", "sei", "sette", "otto", "nove",
             "dieci", "undici", "dodici", "tredici", "quattordici", "quindici", "sedici",
             "diciassette", "diciotto", "diciannove"]
_IT_TENS = ["", "", "venti", "trenta", "quaranta", "cinquanta", "sessanta", "settanta", "ottanta", "novanta"]


def _it_below_100(n):
    if n < 20:
        return _IT_UNITS[n]
    tens, unit = divmod(n, 10)
    word = _IT_TENS[tens]
    if unit in (1, 8):
        word = word[:-1]  # ventuno, ventotto
    if unit == 0:
        return word
    return word + ("tré" if unit == 3 else _IT_UNITS[unit])


def _it_below_1000(n):
    hundreds, rest = divmod(n, 100)
    head = "" if hundreds == 0 else ("cento" if hundreds == 1 else _IT_UNITS[hundreds] + "cento")
    if rest == 0:
        return head or "zero"
    tail = _it_below_100(rest)
    if head and tail.startswith("o"):
        head = head[:-1]  # centottanta
    return head + tail


def italian(n):
    if n < 1000:
        return _it_below_1000(n)
    thousands, rest = divmod(n, 1000)
    head = "mille" if thousands == 1 else _it_below_1000(thousands) + "mila"
    return head + ("" if rest == 0 else _it_below_1000(rest))


_EN_UNITS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
             "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen",
             "eighteen", "nineteen"]
_EN_TENS = ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]


def _en_below_100(n):
    if n < 20:
        return _EN_UNITS[n]
    tens, unit = divmod(n, 10)
    return _EN_TENS[tens] + ("" if unit == 0 else "-" + _EN_UNITS[unit])


def _en_below_1000(n):
    hundreds, rest = divmod(n, 100)
    if hundreds == 0:
        return _en_below_100(rest)
    head = _EN_UNITS[hundreds] + " hundred"
    return head if rest == 0 else head + " " + _en_below_100(rest)


def english(n, year=False):
    """[year] reads 1929 the way people say it: nineteen twenty-nine."""
    if year and 1100 <= n <= 1999:
        high, low = divmod(n, 100)
        return _en_below_100(high) + " " + ("hundred" if low == 0 else
                                            ("oh " + _EN_UNITS[low]) if low < 10 else _en_below_100(low))
    if n < 1000:
        return _en_below_1000(n)
    thousands, rest = divmod(n, 1000)
    head = _en_below_1000(thousands) + " thousand"
    return head if rest == 0 else head + " " + _en_below_1000(rest)


if __name__ == "__main__":
    for n in (1, 3, 8, 13, 21, 23, 28, 100, 180, 1929, 1947, 1950, 1955):
        print(n, italian(n), "|", english(n, year=n > 1000))
