use "buffered"
use "net"
use "net/ssl"


primitive _Open
primitive _Connecting
primitive _Closed
primitive _Error
type State is (_Connecting | _Open | _Closed | _Error)

primitive _Client
primitive _Server
type Mode is (_Client | _Server)

class _TCPConnectionNotify is TCPConnectionNotify
  var _notify: (WebSocketConnectionNotify iso | None)
  var _http_parser: _HttpParser ref = _HttpParser
  let _buffer: Reader ref = Reader
  var _state: State = _Connecting
  var _frame_decoder: _FrameDecoder ref = _FrameDecoder
  var _connection: (WebSocketConnection | None) = None
  var _request: (HandshakeRequest | None) = None
  var _mode: Mode

  new iso client(notify: WebSocketConnectionNotify iso, request: HandshakeRequest iso) =>
    _notify = consume notify
    _mode = _Client
    _request = consume request

  new iso server(notify: WebSocketConnectionNotify iso) =>
    _notify = consume notify
    _mode = _Server

  fun ref connected(conn: TCPConnection ref) =>
    match _request
    | let r: HandshakeRequest => conn.write((consume r).string())
    end

  fun ref received(conn: TCPConnection ref, data: Array[U8] iso, times: USize) : Bool =>
    // Should not handle any data when connection closed or error occured
    if (_state is _Error) or (_state is _Closed) then
      return false
    end

    _buffer.append(consume data)

    try
      match _state
      | _Connecting => _handle_handshake(conn, _buffer)
      | _Open => _handle_frame(conn, _buffer)?
      end
    else
      _state = _Error
    end

    match _state
    | _Error  =>
      match _connection
      | let c: WebSocketConnection =>
        c._close(_frame_decoder.status)
      end
      false
    | _Closed  => false
    | _Open    => true
    | _Connecting => true
    end

  fun ref connect_failed(conn: TCPConnection ref) => None

  fun ref _handle_handshake(conn: TCPConnection ref, buffer: Reader ref) =>
    try
      match _http_parser.parse(_buffer)?
      | let req: HandshakeRequest val =>
        match _mode
        | _Server =>
          let rep = req._handshake()?
          conn.write(rep)
        end
        _state = _Open
        // Create connection
        match (_notify = None, _connection)
        | (let n: WebSocketConnectionNotify iso, None) =>
          _connection = WebSocketConnection(conn, consume n, req)
        end
        conn.expect(2) // expect minimal header
      end
    else
      match _mode
      | _Server => conn.write("HTTP/1.1 400 BadRequest\r\n\r\n")
      | _Client => match _notify = None
        | let n: WebSocketConnectionNotify iso => (consume n).connect_failed(None, "handshake failed") // TODO provide more information here
//        | let n: WebSocketConnectionNotify iso => (consume n).connect_failed(None, "handshake failed") // TODO provide more information here
        end
      end
      conn.dispose()
    end

  fun ref _handle_frame(conn: TCPConnection ref, buffer: Reader ref)? =>
    let frame = _frame_decoder.decode(_buffer)?
    match frame
    | let f: Frame val =>
      match (_connection, f.opcode)
      | (None, Text) => error
      | (let c : WebSocketConnection, Text)   =>
        c._text_received(f.data as String)
      | (let c : WebSocketConnection, Binary) =>
        c._binary_received(f.data as Array[U8] val)
      | (let c : WebSocketConnection, Ping)   =>
        c._ping_received(f.data as Array[U8] val)
        c._send_pong(f.data as Array[U8] val)
      | (let c : WebSocketConnection, Pong)   =>
        c._pong_received(f.data as Array[U8] val)
      | (let c : WebSocketConnection, Close)  => c._close(1000)
      end
      conn.expect(2) // expect next header
    | let n: USize =>
      conn.expect(n) // need more data to parse a frame
    end

  fun ref closed(conn: TCPConnection ref) =>
    // When TCP connection is closed, enter CLOSED state.
    // See https://tools.ietf.org/html/rfc6455#section-7.1.4
    _state = _Closed
    match _connection
    | let c: WebSocketConnection =>
      c._notify_closed()
    end

// vi: sw=2 sts=2 ts=2 et
