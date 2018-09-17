# lua libp2p

This is the start of an implementation of libp2p in lua.
It does a few things, i'm not great at lua, but it's been fun to write

## Dependencies
These modules depend on some lua packages, `luasocket` and `lua-protobuf`. You can install these with luarocks:
```
luarocks install luasocket
luarocks install lua-protobuf
```

## Libp2p implementation notes
- First, implement multistream select
	- Requires implementing Uvarint parsing
	- Helpful to use multistream test daemon
- Skip encryption for now, use '/plaintext/1.0.0' to move forward
- Implement multiplex, [spec here](https://github.com/libp2p/mplex)
	- For every incoming stream you get, run multistream select negotiate
- Implement the 'switch'
	- switch (called 'swarm' in go-ipfs) handles dialing peers, and incoming connects
	- exposes 'NewStream(Protocol)'
	- is given protocol handlers to call for new incoming streams
- Implement identify
	- Grab the protobuf, get a parser working for that
	- When you get a new stream for identify, fill out that protobuf and send it, with a uvarint length prefix
	- When you open a stream for identify (new stream, multistream select /ipfs/id/1.0.0) you read a length delimited protobuf from the other peer
- Implement ping
	- Open stream, multistream negotiate /ipfs/ping/1.0.0
	- Write a random 32 byte value
	- read back that same 32 byte value
	- time that process
	- repeat as often as needed
- Testing: Run a go-ipfs node with `ipfs daemon --disable-transport-encryption`

TODO:
- [ ] implement secio
- [ ] implement multiaddr
- [ ] write more TODOs
