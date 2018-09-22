use "net"
use "net/ssl"

primitive WebSocketClient

  fun apply(auth: TCPConnectAuth, notify: WebSocketConnectionNotify iso, host: String, service: String, origin: String, method: String, resource: String, ssl_context: (SSLContext | None) = None): TCPConnection ? =>
    TCPConnection.create(
      auth,
      match ssl_context
      | None => _TCPConnectionNotify.client(consume notify, HandshakeRequest.request(resource, host, origin, method))
      | let ssl: SSLContext => SSLConnection(_TCPConnectionNotify.client(consume notify, HandshakeRequest.request(resource, host, origin, method)), ssl.client()?)
      end,
      host,
      service
      )

// vi: sw=2 sts=2 ts=2 et
