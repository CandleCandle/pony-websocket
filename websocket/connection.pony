use "net"
use "time"
use "random"

actor WebSocketConnection
  """
  A wrapper around a TCP connection, provides data-sending functionality.
  """

  let _notify: WebSocketConnectionNotify
  let _tcp: TCPConnection
  var _closed: Bool = false
  let request: HandshakeRequest val
//  let _random: Rand ref
//  let _random: (None | Rand)
  let _server: Bool

  new client(
    tcp: TCPConnection,
    notify: WebSocketConnectionNotify iso,
    request': HandshakeRequest val)
  =>
    _notify = consume notify
    _tcp = tcp
    request = request'
//    (let s: I64, let n: I64) = Time.now()
//    _random = Rand(s.u64(), n.u64()).>u128()
    _server = false
    _notify.opened(this)

  new server(
    tcp: TCPConnection,
    notify: WebSocketConnectionNotify iso,
    request': HandshakeRequest val)
  =>
    _notify = consume notify
    _tcp = tcp
    request = request'
//    _random = Rand(0, 0).>u128()
    _server = true
    //_random = None
    _notify.opened(this)

  fun _gen_masking_key(): (U32 | None) =>
    if not _server then
      (let s: I64, let n: I64) = Time.now()
      Rand(s.u64(), n.u64()).>u128().u32()
//      _random.u32()
    else None end
//    match _random
//    | None => None
//    | let r: Rand => r.u32()
//    end

  fun send_text(text: String val) =>
    """
    Send text data (without fragmentation), text must be encoded in utf-8.
    """
    if not _closed then
      _tcp.writev(Frame.text(text, _gen_masking_key()).build())
    end

  be send_text_be(text: String val) =>
    send_text(text)

  fun send_binary(data: Array[U8] val) =>
    """
    Send binary data (without fragmentation)
    """
    if not _closed then
      _tcp.writev(Frame.binary(data, _gen_masking_key()).build())
    end

  be send_binary_be(data: Array[U8] val) =>
    send_binary(data)

  fun ref close(code: U16 = 1000) =>
    """
    Initiate closure, all data sending is ignored after this call.
    """
    if not _closed then
      _tcp.writev(Frame.close(code, _gen_masking_key()).build())
      _closed = true
    end

  be close_be(code: U16 = 1000) =>
    close(code)

  be send_ping(data: Array[U8] val = []) =>
    """
    Send a ping frame.
    """
    if not _closed then
      _tcp.writev(Frame.ping(data, _gen_masking_key()).build())
    end
    _notify.ping_sent(this, data)

  be _send_pong(data: Array[U8] val) =>
    """
    Send a pong frame.
    """
    if not _closed then
      _tcp.writev(Frame.pong(data, _gen_masking_key()).build())
    end
    _notify.pong_sent(this, data)

  be _close(code: U16 = 100) =>
    """
    Send a close frame and close the TCP connection, all data sending is
    ignored after this call.
    On client-initiated closure, send a close frame and close the connection.
    On server-initiated closure, close the connection without sending another
    close frame.
    """
    if not _closed then
      _tcp.writev(Frame.close(code, _gen_masking_key()).build())
      _closed = true
    end
    _tcp.dispose()

  be _text_received(text: String) =>
    _notify.text_received(this, text)

  be _binary_received(data: Array[U8] val) =>
    _notify.binary_received(this, data)

  be _ping_received(data: Array[U8] val) =>
    _notify.ping_received(this, data)

  be _pong_received(data: Array[U8] val) =>
    _notify.pong_received(this, data)

  be _notify_closed() =>
    _notify.closed(this)

// vi: sw=2 sts=2 ts=2 et
