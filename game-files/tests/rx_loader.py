"""Load RPG Maker XP marshal files, including maps with circular references.

rubymarshal raises on a link to an object that is still being built. RPG Maker
move routes do that. This reader publishes arrays, hashes, and objects before
filling them, which is how Ruby's marshal format works.
"""

from __future__ import annotations

import re

from rubymarshal import constants as C
from rubymarshal.classes import (
    Extended,
    Module,
    RubyObject,
    RubyString,
    UserDef,
    UsrMarshal,
)
from rubymarshal.reader import Reader


class CycleSafeReader(Reader):
    def read(self, in_ivar=False):
        result = None
        object_index = None
        re_flags = None
        token = self.fd.read(1)
        if token in (
            C.TYPE_CLASS,
            C.TYPE_MODULE,
            C.TYPE_FLOAT,
            C.TYPE_BIGNUM,
            C.TYPE_STRING,
            C.TYPE_REGEXP,
            C.TYPE_ARRAY,
            C.TYPE_HASH,
            C.TYPE_STRUCT,
            C.TYPE_OBJECT,
            C.TYPE_DATA,
            C.TYPE_USRMARSHAL,
            C.TYPE_USERDEF,
        ):
            object_index = len(self.objects)
            self.objects.append(None)

        if token == C.TYPE_NIL:
            pass
        elif token == C.TYPE_TRUE:
            result = True
        elif token == C.TYPE_FALSE:
            result = False
        elif token == C.TYPE_IVAR:
            result = self.read(in_ivar=True)
        elif token == C.TYPE_STRING:
            result = self.read_blob()
        elif token == C.TYPE_SYMBOL:
            result = self.read_symreal()
        elif token == C.TYPE_FIXNUM:
            result = self.read_long()
        elif token == C.TYPE_ARRAY:
            count = self.read_long()
            result = []
            self.objects[object_index] = result
            for _ in range(count):
                result.append(self.read())
        elif token == C.TYPE_HASH:
            count = self.read_long()
            result = {}
            self.objects[object_index] = result
            for _ in range(count):
                key = self.ensure_hashable(self.read())
                result[key] = self.read()
        elif token == C.TYPE_FLOAT:
            floatn = self.read_blob().split(b"\0")
            result = float(floatn[0].decode("utf-8"))
        elif token == C.TYPE_BIGNUM:
            sign = 1 if self.fd.read(1) == b"+" else -1
            count = self.read_long()
            result = 0
            factor = 1
            for _ in range(count):
                result += self.read_short() * factor
                factor *= 2**16
            result *= sign
        elif token == C.TYPE_REGEXP:
            result = self.read_blob()
            options = ord(self.fd.read(1))
            re_flags = 0
            if options & 1:
                re_flags |= re.IGNORECASE
            if options & 4:
                re_flags |= re.MULTILINE
        elif token == C.TYPE_USRMARSHAL:
            class_symbol = self.read()
            attr_list = self.read()
            class_name = class_symbol.name
            python_class = self.registry.get(class_name, UsrMarshal)
            result = python_class(class_name)
            self.objects[object_index] = result
            result.marshal_load(attr_list)
        elif token == C.TYPE_SYMLINK:
            result = self.read_symlink()
        elif token == C.TYPE_LINK:
            link_id = self.read_long()
            if link_id >= len(self.objects):
                raise ValueError(
                    "invalid link destination: %d should be lower than %d."
                    % (link_id, len(self.objects))
                )
            result = self.objects[link_id]
            if result is None:
                raise ValueError(
                    "invalid link destination: Object id %d is not yet unmarshaled."
                    % link_id
                )
        elif token == C.TYPE_USERDEF:
            class_symbol = self.read()
            private_data = self.read_blob()
            class_name = class_symbol.name
            python_class = self.registry.get(class_name, UserDef)
            result = python_class(class_name)
            result._load(private_data)
        elif token == C.TYPE_MODULE:
            result = Module(self.read_blob().decode(), None)
        elif token == C.TYPE_OBJECT:
            class_symbol = self.read()
            class_name = class_symbol.name
            python_class = self.registry.get(class_name, RubyObject)
            result = python_class(class_name, {})
            self.objects[object_index] = result
            result.set_attributes(self.read_attributes())
        elif token == C.TYPE_EXTENDED:
            result = Extended(self.read_blob(), None)
        elif token == C.TYPE_CLASS:
            class_name = self.read_blob().decode()
            if class_name in self.registry:
                result = self.registry[class_name]
            else:
                result = type(
                    class_name.rpartition(":")[2],
                    (RubyObject,),
                    {"ruby_class_name": class_name},
                )
        elif token == C.TYPE_STRUCT:
            raise ValueError("marshal struct is not used by map files")
        elif token == C.TYPE_DATA:
            raise ValueError("marshal data is not used by map files")
        else:
            raise ValueError("token %r is not recognized" % token)

        if in_ivar:
            attributes = self.read_attributes()
            if token in (C.TYPE_STRING, C.TYPE_REGEXP):
                encoding = self._get_encoding(attributes)
                try:
                    result = result.decode(encoding)
                except UnicodeDecodeError:
                    result = result.decode("unicode-escape")
                if attributes and token == C.TYPE_STRING:
                    result = RubyString(result, attributes)
            elif attributes and hasattr(result, "set_attributes"):
                result.set_attributes(attributes)

        if token == C.TYPE_REGEXP:
            result = re.compile(str(result), re_flags)

        if object_index is not None and token not in (
            C.TYPE_ARRAY,
            C.TYPE_HASH,
            C.TYPE_OBJECT,
            C.TYPE_USRMARSHAL,
        ):
            self.objects[object_index] = result
        return result


def load_rxdata(path):
    with open(path, "rb") as handle:
        header = handle.read(2)
        if header != b"\x04\x08":
            raise ValueError("Not a Ruby marshal file: %s" % path)
        return CycleSafeReader(handle).read()
