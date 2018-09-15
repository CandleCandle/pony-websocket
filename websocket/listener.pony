use "net"
use "net/ssl"

actor WebSocketListener
  let _tcp_listner: TCPListener

  new create(auth: TCPListenerAuth, notify: WebSocketListenNotify iso, host: String, service: String, ssl_context: (SSLContext | None) = None) =>
    _tcp_listner = TCPListener(auth, recover _TCPListenNotify(consume notify, ssl_context) end, host, service)

class _TCPListenNotify is TCPListenNotify
  var notify: WebSocketListenNotify iso
  let ssl_context: (SSLContext | None)

  new create(notify': WebSocketListenNotify iso, ssl_context': (SSLContext | None) = None) =>
    notify = consume notify'
    ssl_context = ssl_context'

  fun ref connected(listen: TCPListener ref): TCPConnectionNotify iso^ ? =>
    let n = notify.connected()
    match ssl_context
    | let ctx: SSLContext =>
      let ssl = ctx.server()?
      SSLConnection(_TCPConnectionNotify.server(consume n), consume ssl)
    else
      _TCPConnectionNotify.server(consume n)
    end

  fun ref not_listening(listen: TCPListener ref) =>
    notify.not_listening()

  fun ref listening(listen: TCPListener ref) =>
    notify.listening()

