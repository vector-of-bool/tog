import sys
import socket
import struct
import json

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('localhost', 8263))

data = json.dumps({
    'method': 'compile',
    'params': sys.argv,
}).encode()

header = struct.pack('>l', len(data))
s.send(header + data)