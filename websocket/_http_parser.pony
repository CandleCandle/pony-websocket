use "buffered"
use "collections"

primitive _ExpectRequest
primitive _ExpectResponse
primitive _ExpectHeaders
primitive _ExpectError

type _ParserState is (_ExpectResponse | _ExpectRequest | _ExpectHeaders | _ExpectError)

class _HttpParser
  """
  A cutdown version of net/http/_http_parser, just parse request line and headers.
  """

  var _request: HandshakeRequest trn = HandshakeRequest
  var _state: _ParserState = _ExpectRequest

  new server() =>
    _state = _ExpectRequest

  new client() =>
    _state = _ExpectResponse

  fun ref parse(buffer: Reader ref): (HandshakeRequest val | None) ? =>
    """
    Return a HandshakeRequest on success.
    Return None for more data.
    """
    match _state
    | _ExpectResponse => _parse_response(buffer)?
    | _ExpectRequest => _parse_request(buffer)?
    | _ExpectHeaders => _parse_headers(buffer)?
    end

  fun ref _parse_request(buffer: Reader): None ? =>
    """
    Parse request-line: "<Method> <URL> <Proto>"
    """
    try
      let line = buffer.line()?
      try
        let method_end = line.find(" ")?
        _request.method = line.substring(0, method_end)
        let url_end = line.find(" ", method_end + 1)?
        _request.resource = line.substring(method_end + 1, url_end)
        _state = _ExpectHeaders
      else
        _state = _ExpectError
      end
    else
      return None // expect more data for a line
    end

    if _state is _ExpectError then error end // Not a valid request-line

  fun ref _parse_response(buffer: Reader): None ? =>
    """
    "HTTP/1.1 101 Web Socket Protocol Handshake"
    """
    try
      let line = buffer.line()?
      try
        let protocol_end = line.find(" ")?
        @printf[I32]("protocol end: %d\n".cstring(), protocol_end)
        let code_end = line.find(" ", protocol_end + 1)?
        @printf[I32]("code end: %d\n".cstring(), code_end)
        _request.code = line.substring(protocol_end + 1, code_end)
        _request.message = line.substring(code_end + 1)
        _state = _ExpectHeaders
      else
        _state = _ExpectError
      end
    else
      return None // expect more data for a line
    end

    if _state is _ExpectError then error end // Not a valid response-line

  fun ref _parse_headers(buffer: Reader): (HandshakeRequest val | None) ? =>
    while true do
      try
        let line = buffer.line()?
        if line.size() == 0 then
          _state = _ExpectRequest
          return _request = HandshakeRequest // Finish parsing and reset
        else
          try
            _process_header(consume line)?
          else
            _state = _ExpectError
            break
          end
        end
      else
        return None
      end
    end

    if _state is _ExpectError then error end

  fun ref _process_header(line: String iso) ? =>
    let i = line.find(":")?
    (let key, let value) = (consume line).chop(i.usize())
    key.>strip().lower_in_place()
    value.>shift()?.strip()
    _request._set_header(consume key, consume value)

// vi: sw=2 ts=2 sts=2 et
