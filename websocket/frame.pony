use "buffered"

primitive Continuation  fun apply(): U8 => 0x00
primitive Text          fun apply(): U8 => 0x01
primitive Binary        fun apply(): U8 => 0x02
primitive Close         fun apply(): U8 => 0x08
primitive Ping          fun apply(): U8 => 0x09
primitive Pong          fun apply(): U8 => 0x0A
type Opcode is (Continuation | Text | Binary | Ping | Pong | Close)

class trn Frame
  var opcode: Opcode

  // Unmasked data.
  var data: (String val | Array[U8 val] val)

  let _masking_key: (U32 | None)

  new iso create(opcode': Opcode, data':  (String val | Array[U8 val] iso), masking_key': (None | U32) = None) =>
    opcode = opcode'
    _masking_key = masking_key'
    data = _mask(masking_key', consume data')

  new iso text(data': String = "", masking_key': (None | U32) = None) =>
    opcode = Text
    _masking_key = masking_key'
//    data = consume data'
    data = _mask(masking_key', consume data')

  new iso ping(data': Array[U8 val] val, masking_key': (None | U32) = None) =>
    opcode = Ping
    _masking_key = masking_key'
//    data = data'
    data = _mask(masking_key', recover iso data'.clone() end)

  new iso pong(data': Array[U8 val] val, masking_key': (None | U32) = None) =>
    opcode = Pong
    _masking_key = masking_key'
//    data = data'
    data = _mask(masking_key', recover iso data'.clone() end)

  new iso binary(data': Array[U8 val] val, masking_key': (None | U32) = None) =>
    opcode = Binary
    _masking_key = masking_key'
//    data = data'
    data = _mask(masking_key', recover iso data'.clone() end)

  new iso close(code: U16 = 1000, masking_key': (None | U32) = None) =>
    opcode = Close
    _masking_key = masking_key'
//    data = [U8.from[U16](code.shr(8)); U8.from[U16](code and 0xFF)]
    data = _mask(masking_key', recover iso [U8.from[U16](code.shr(8)); U8.from[U16](code and 0xFF)] end)

  fun tag _mask(masking_key': (None | U32) = None, data':  (String val | Array[U8 val] iso)): (String val | Array[U8 val] val) =>
    match masking_key'
    | let k: U32 =>
      _Masker([
      (k.shr(24) and 0xFF).u8()
      (k.shr(16) and 0xFF).u8()
      (k.shr( 8) and 0xFF).u8()
      (k         and 0xFF).u8()
      ],
      match consume data'
      | let a: Array[U8 val] iso => consume a
      | let s: String val => recover iso s.array().clone() end
      end
    )
    | None => data'
    end


  // Build a frame that the server can send to client, data is not masked
  fun val build(): Array[(String val | Array[U8 val] val)] iso^ =>
    let writer: Writer = Writer

    match opcode
    | Text   => writer.u8(0b1000_0001)
    | Binary => writer.u8(0b1000_0010)
    | Ping   => writer.u8(0b1000_1001)
    | Pong   => writer.u8(0b1000_1010)
    | Close =>
      writer.u8(0b1000_1000)
      writer.u8(0x2)      // two bytes for code
      writer.write(data)  // status code
      return writer.done()
    end

    let mask_bit: U8 = match _masking_key
    | let u: U32 => 0b1000_0000
    | None => 0b0000_0000
    end

    var payload_len = data.size()
    if payload_len < 126 then
      writer.u8(U8.from[USize](payload_len) or mask_bit)
    elseif payload_len < 65536 then
      writer.u8(126  or mask_bit)
      writer.u16_be(U16.from[USize](payload_len))
    else
      writer.u8(127 or mask_bit)
      writer.u64_be(U64.from[USize](payload_len))
    end
    match _masking_key
    | let k: U32 =>
      writer.u32_be(k)
    end
    writer.write(data)
    writer.done()

// vi: sw=2 sts=2 ts=2 et
