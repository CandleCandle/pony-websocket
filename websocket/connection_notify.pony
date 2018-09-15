interface WebSocketConnectionNotify

  fun ref opened(conn: WebSocketConnection ref) =>
    None

  fun ref closed(conn: WebSocketConnection ref) =>
    None

  fun ref text_received(conn: WebSocketConnection ref, text: String): None =>
    None

  fun ref binary_received(conn: WebSocketConnection ref, data: Array[U8 val] val): None =>
    None

  fun ref connect_failed(conn: (WebSocketConnection ref | None), reason: String) =>
    None

  fun ref ping_sent(conn: WebSocketConnection ref, data: Array[U8] val) =>
    None

  fun ref pong_sent(conn: WebSocketConnection ref, data: Array[U8] val) =>
    None

  fun ref ping_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
    None

  fun ref pong_received(conn: WebSocketConnection ref, data: Array[U8] val) =>
    None

// vi: sw=2 ts=2 sts=2 et
