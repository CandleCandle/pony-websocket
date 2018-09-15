use "net"
use "net/ssl"

actor WebSocketClient

  new create(auth: TCPConnectAuth, notify: WebSocketConnectionNotify iso, host: String, service: String, origin: String, method: String, resource: String, ssl_context: (SSLContext | None) = None) =>
    TCPConnection.create(
      auth,
      _TCPConnectionNotify.client(consume notify, HandshakeRequest.request(resource, host, origin, method)),
      host,
      service
      )


