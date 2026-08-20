import os
import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Python equivalent of our pure Ruby tokenizer & parser to verify logic
def parse_simple_json(str_content):
    tokens = []
    i = 0
    length = len(str_content)
    while i < length:
        ch = str_content[i]
        if ch in (' ', '\t', '\n', '\r'):
            i += 1
        elif ch in ('{', '}', '[', ']', ':', ','):
            tokens.append(ch)
            i += 1
        elif ch == '"':
            j = i + 1
            while j < length:
                if str_content[j] == '\\':
                    j += 2
                elif str_content[j] == '"':
                    break
                else:
                    j += 1
            tokens.append(str_content[i:j+1])
            i = j + 1
        else:
            j = i
            while j < length and str_content[j] not in (' ', '\t', '\n', '\r', '{', '}', '[', ']', ':', ','):
                j += 1
            tokens.append(str_content[i:j])
            i = j
            
    def parse_string(token):
        if len(token) <= 2:
            return ""
        raw = token[1:-1]
        import re
        def replace_escape(m):
            c = m.group(1)
            mapping = {'"': '"', '\\': '\\', '/': '/', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t'}
            return mapping.get(c, c)
        raw = re.sub(r'\\(["\\/bfnrt])', replace_escape, raw)
        raw = re.sub(r'\\u([0-9a-fA-F]{4})', lambda m: chr(int(m.group(1), 16)), raw)
        return raw

    def parse_val(pos):
        token = tokens[pos]
        if token == "{":
            return parse_obj(pos)
        elif token == "[":
            return parse_arr(pos)
        elif token.startswith('"'):
            return parse_string(token), pos + 1
        elif token == "true":
            return True, pos + 1
        elif token == "false":
            return False, pos + 1
        elif token == "null":
            return None, pos + 1
        else:
            return token, pos + 1

    def parse_obj(pos):
        obj = {}
        pos += 1
        if tokens[pos] == "}":
            return obj, pos + 1
        while True:
            key = parse_string(tokens[pos])
            pos += 1
            assert tokens[pos] == ":"
            pos += 1
            val, pos = parse_val(pos)
            obj[key] = val
            if tokens[pos] == ",":
                pos += 1
            elif tokens[pos] == "}":
                pos += 1
                break
            else:
                break
        return obj, pos

    def parse_arr(pos):
        arr = []
        pos += 1
        if tokens[pos] == "]":
            return arr, pos + 1
        while True:
            val, pos = parse_val(pos)
            arr.append(val)
            if tokens[pos] == ",":
                pos += 1
            elif tokens[pos] == "]":
                pos += 1
                break
            else:
                break
        return arr, pos

    res, _ = parse_val(0)
    return res

json_path = os.path.join("PBS", "translations.json")
with open(json_path, "r", encoding="utf-8") as f:
    content = f.read()

parsed = parse_simple_json(content)
print("Parsed Result:")
print(json.dumps(parsed, ensure_ascii=False, indent=2))
assert "translations" in parsed
translations = parsed["translations"]
assert isinstance(translations, (dict, list))
if isinstance(translations, dict):
    assert "MSG_NOT_READY" in translations
    assert translations["MSG_NOT_READY"]["he"] == "נראה שזה עדיין לא מוכן..."
    assert translations["MSG_NOT_READY"]["en"] == "Looks like this is not ready..."
print("\n[SUCCESS] Tokenizer & Parser logic verified for key-based translation structure!")
