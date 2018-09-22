use "websocket"
use "net"
use "net/ssl"
use "random"
use "encode/base64"
use "time"
use "format"
use "buffered"
use "files"


primitive RandomBase64
	fun apply(n: USize): String =>
		let res = Array[U8].init(0, n)
		var i: USize = 0
		(let a, let b) = Time.now()
		let rand = Rand(a.u64(), b.u64())
		rand.u8() // first read is always predicatable. (wtf!)
		try
			while i < n do
				res.update(i, rand.u8())?
				i = i + 1
			end
		end
		Base64.encode(res)

primitive HexData
	fun apply(data: Array[U8] val): String val =>
		recover val
			let result = String(data.size()*2)
			for b in data.values() do
				result.append(Format.int[U8](b, FormatHexBare where width = 2, fill = '0'))
			end
			result
		end

primitive DataConcat
	fun apply(len: USize, input: Array[ByteSeq] val): Array[U8] val =>
		recover val
			let result = Array[U8](len)
			for seq in input.values() do
				match seq
				| let s: String val => result.append(s.array())
				| let a: Array[U8] val => result.append(a)
				end
			end
			result
		end

actor Main
	new create(env: Env) =>
		try
			let wsconnnotify = EchoListenNotify.create()
			let conn = WebSocketClient(
				TCPConnectAuth(env.root as AmbientAuth),
				consume wsconnnotify,
				"echo.websocket.org",
//				"443",
				"80",
				"http://websocket.org/",
				"GET",
				"/",
				None
//				recover val SSLContext.>set_authority(None, FilePath(env.root as AmbientAuth, "/etc/ssl/certs")?)? end
				)?
		end

class Pinger is TimerNotify
	let _conn: WebSocketConnection

	new iso create(conn: WebSocketConnection) =>
		_conn = conn

	fun ref apply(timer: Timer, count: U64): Bool =>
		(let s: I64, let n: I64) = Time.now()
		let writer = Writer
		writer.i64_be(s)
		writer.i64_be(n)
		_conn.send_ping(DataConcat(writer.size(), writer.done()))
		true

class DataThinger is TimerNotify
	let _conn: WebSocketConnection

	new iso create(conn: WebSocketConnection) =>
		_conn = conn

	fun ref apply(timer: Timer, count: U64): Bool =>
		_conn.send_text_be("data")
		true

class iso EchoListenNotify is WebSocketConnectionNotify
	var _counter: USize = 0
	// A websocket connection enters the OPEN state
	fun ref opened(conn: WebSocketConnection ref) =>
		@printf[I32]("Connected\n".cstring())
		@printf[I32]("request: \n  method: '%s'\n  resource: '%s'\n  code: '%s'\n  message: '%s'\n".cstring(), conn.request.method.cstring(), conn.request.resource.cstring(), conn.request.code.cstring(), conn.request.message.cstring())
		for (k, v) in conn.request.headers.pairs() do
			@printf[I32]("    %s => %s\n".cstring(), k.cstring(), v.cstring())
		end

		conn.send_text("data")
		Timers.create(20).apply(Timer(Pinger.create(conn), 1_000_000_000, 7_000_000_000))
		Timers.create(20).apply(Timer(DataThinger.create(conn), 32_000_000_000, 32_000_000_000))

	fun ref ping_sent(conn: WebSocketConnection ref, data: Array[U8] val) =>
		@printf[I32]("Ping sent: %s\n".cstring(), HexData(data).cstring())

	fun ref pong_sent(conn: WebSocketConnection ref, data: Array[U8] val) =>
		@printf[I32]("Pong sent: %s\n".cstring(), HexData(data).cstring())

	fun ref ping_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
		@printf[I32]("Ping received: %s\n".cstring(), HexData(data).cstring())

	fun ref pong_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
		let reader = Reader
		reader.append(data)
		(let s: I64, let n: I64) = Time.now()
		var os: I64 = s
		var on: I64 = n
		try
			os = reader.i64_be()?
			on = reader.i64_be()?
		end
		@printf[I32]("Pong received: %s, %d s, %d ns\n".cstring(), HexData(data).cstring(), (s-os), (n-on))

	fun ref connect_failed(conn: (None | WebSocketConnection ref), reason: String) =>
		@printf[I32]("Connection failed: %s\n".cstring(), reason.cstring())

	// UTF-8 text data received
	fun ref text_received(conn: WebSocketConnection ref, text: String) =>
		// Send the text back
		@printf[I32]("received text: %s, count: %d\n".cstring(), text.cstring(), _counter)
		_counter = _counter+1
//		conn.send_text(text)

	// Binary data received
	fun ref binary_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
		@printf[I32]("received binary: %s\n".cstring(), HexData(data).cstring())
//		conn.send_binary(data)

	// A websocket connection enters the CLOSED state
	fun ref closed(conn: WebSocketConnection ref) =>
		@printf[I32]("Connection closed\n".cstring())

// vi: sw=4 sts=4 ts=4 noet
