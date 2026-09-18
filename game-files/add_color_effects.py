import os
import sys
import struct
import io
import rubymarshal.reader
import rubymarshal.writer
from rubymarshal.writer import (
    TYPE_IVAR, TYPE_USERDEF, TYPE_OBJECT, TYPE_STRING, TYPE_FLOAT, TYPE_ARRAY, TYPE_HASH, Symbol, UserDef, RubyObject
)

class CorrectWriter(rubymarshal.writer.Writer):
    def write_string(self, obj):
        if self.must_write(obj):
            self.fd.write(TYPE_STRING)
            bdata = obj.encode('utf-8')
            self.write_long(len(bdata))
            self.fd.write(bdata)

    def write_bytes(self, obj):
        if self.must_write(obj):
            self.fd.write(TYPE_STRING)
            self.write_long(len(obj))
            self.fd.write(obj)

    def write_ruby_string(self, obj):
        if obj.attributes:
            self.fd.write(TYPE_IVAR)
        if self.must_write(obj):
            self.fd.write(TYPE_STRING)
            bdata = obj.encode('utf-8')
            self.write_long(len(bdata))
            self.fd.write(bdata)
            if obj.attributes:
                self.write_attributes(obj.attributes)

    def write_float(self, obj):
        if self.must_write(obj):
            self.fd.write(TYPE_FLOAT)
            bdata = ('%.15g' % obj).encode('utf-8')
            self.write_long(len(bdata))
            self.fd.write(bdata)

    def write_list(self, obj):
        if self.must_write(obj):
            self.fd.write(TYPE_ARRAY)
            self.write_long(len(obj))
            for item in obj:
                self.write(item)

    def write_dict(self, obj):
        if self.must_write(obj):
            self.fd.write(TYPE_HASH)
            self.write_long(len(obj))
            for k, v in obj.items():
                self.write(k)
                self.write(v)

    def write_user_def(self, obj):
        if obj.attributes:
            self.fd.write(TYPE_IVAR)
        if self.must_write(obj):
            self.fd.write(TYPE_USERDEF)
            self.write(Symbol(obj.ruby_class_name))
            bdata = obj._dump()
            self.write_long(len(bdata))
            self.fd.write(bdata)
            if obj.attributes:
                self.write_attributes(obj.attributes)

    def write_ruby_object(self, obj):
        if self.must_write(obj):
            self.fd.write(TYPE_OBJECT)
            self.write(Symbol(obj.ruby_class_name))
            self.write_attributes(obj.attributes)

def create_tone(r, g, b, gray=0):
    t = UserDef()
    t.ruby_class_name = 'Tone'
    t._private_data = struct.pack('<dddd', float(r), float(g), float(b), float(gray))
    return t

def create_cmd(code, parameters, indent=0):
    return RubyObject('RPG::EventCommand', {
        '@code': code,
        '@indent': indent,
        '@parameters': parameters
    })

def create_condition(switch1_valid=False, switch1_id=1):
    return RubyObject('RPG::Event::Page::Condition', {
        '@switch1_valid': switch1_valid,
        '@switch1_id': switch1_id,
        '@switch2_valid': False,
        '@switch2_id': 1,
        '@variable_valid': False,
        '@variable_id': 1,
        '@variable_value': 0,
        '@self_switch_valid': False,
        '@self_switch_ch': b'A'
    })

def create_graphic():
    return RubyObject('RPG::Event::Page::Graphic', {
        '@tile_id': 0,
        '@character_name': b'',
        '@character_hue': 0,
        '@direction': 2,
        '@pattern': 0,
        '@opacity': 255,
        '@blend_type': 0
    })

def create_move_route():
    return RubyObject('RPG::MoveRoute', {
        '@repeat': True,
        '@skippable': False,
        '@list': [create_cmd(0, [])]
    })

def create_page(trigger, condition, commands):
    cmd_objs = [create_cmd(c[0], c[1]) for c in commands]
    cmd_objs.append(create_cmd(0, []))
    return RubyObject('RPG::Event::Page', {
        '@condition': condition,
        '@graphic': create_graphic(),
        '@move_type': 0,
        '@move_speed': 3,
        '@move_frequency': 3,
        '@move_route': create_move_route(),
        '@walk_anime': True,
        '@step_anime': False,
        '@direction_fix': False,
        '@through': False,
        '@always_on_top': False,
        '@trigger': trigger,
        '@list': cmd_objs
    })

def main():
    map_file = os.path.join('Data', 'Map086.rxdata')
    with open(map_file, 'rb') as f:
        map_data = rubymarshal.reader.load(f)

    # Page 1: Normal screen tone when Switch 104 (spacesheep-music-cool) is OFF
    page1_cmds = [
        (223, [create_tone(0, 0, 0, 0), 20]),
        (106, [60])
    ]
    p1 = create_page(trigger=4, condition=create_condition(False, 1), commands=page1_cmds)

    # Page 2: Color filter cycling (Light Red -> Light Blue -> Light Green) with 60 frames wait when Switch 104 is ON
    page2_cmds = [
        (223, [create_tone(100, -30, -30, 0), 20]),
        (106, [60]),
        (223, [create_tone(-30, -30, 100, 0), 20]),
        (106, [60]),
        (223, [create_tone(-30, 100, -30, 0), 20]),
        (106, [60])
    ]
    p2 = create_page(trigger=4, condition=create_condition(True, 104), commands=page2_cmds)

    ev15 = RubyObject('RPG::Event', {
        '@id': 15,
        '@name': b'EV015-COLOR-EFFECTS',
        '@x': 22,
        '@y': 18,
        '@pages': [p1, p2]
    })

    map_data.attributes['@events'][15] = ev15

    buf = io.BytesIO()
    buf.write(b'\x04\x08')
    writer = CorrectWriter(buf)
    writer.write(map_data)
    
    with open(map_file, 'wb') as f:
        f.write(buf.getvalue())

    print(f"Successfully updated {map_file} with Event 15 (EV015-COLOR-EFFECTS)!")

if __name__ == "__main__":
    main()
