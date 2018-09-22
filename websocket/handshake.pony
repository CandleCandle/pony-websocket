use "collections"
use "encode/base64"
use "crypto"
use "random"
use "time"

class HandshakeRequest
  var method: String = ""
  var resource: String = ""
  var code: String = ""
  var message: String = ""
  let headers: Map[String, String] = headers.create(32)

  new trn create() =>
    None

  new iso request(resource': String, host: String, origin: String, method': String = "GET") =>
    resource = resource'
    method = method'
    headers("Host") = host
    headers("Origin") = origin
    headers("Connection") = "upgrade"
    headers("Upgrade") = "websocket"
    headers("Sec-WebSocket-Version") = "13"
    headers("Sec-WebSocket-Key") = _RandomBase64(16)

  fun string(): String val =>
    let result = recover iso String end
    result.>append(method).>append(" ").>append(resource).>append(" HTTP/1.1\r\n")
    for (hk, hv) in headers.pairs() do
      result.>append(hk).>append(": ").>append(hv).>append("\r\n")
    end
    result.>append("\r\n")
    consume result

  fun _handshake(): String ? =>
    try
      let version = headers("sec-websocket-version")?
      let key = headers("sec-websocket-key")?
      let upgrade = headers("upgrade")?
      let connection = headers("connection")?

      if version.lower() != "13" then error end
      if upgrade.lower() != "websocket" then error end
      var conn_upgrade = false
      for s in connection.split_by(",").values() do
        if s.lower().>strip(" ") == "upgrade" then
          conn_upgrade = true
          break
        end
      end
      if not conn_upgrade then error end

      _response(_accept_key(key))
    else
      error
    end

  fun _response(key: String): String =>
    "HTTP/1.1 101 Switching Protocols\r\n"
      + "Upgrade: websocket\r\n"
      + "Connection: Upgrade\r\n"
      + "Sec-WebSocket-Accept:" + key
      + "\r\n\r\n"

  fun _accept_key(key: String): String =>
    let c = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let digest = Digest.sha1()
    try
      digest.append(c)?
    end
    let d = digest.final()
    Base64.encode(d)

  fun ref _set_header(key: String, value: String) =>
    headers(key) = value

primitive _RandomBase64
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


// vi: sw=2 sts=2 ts=2 et
