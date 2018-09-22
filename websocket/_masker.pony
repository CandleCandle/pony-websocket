
primitive _Masker
  fun apply(mask_key: Array[U8], payload: Array[U8 val] iso): Array[U8 val] iso^ =>
    let p = consume payload
    let size = p.size()
    var i: USize = 0
    try
      let m1 = mask_key(0)?
      let m2 = mask_key(1)?
      let m3 = mask_key(2)?
      let m4 = mask_key(3)?
      while (i + 4) < size do
        p(i)?     = p(i)?     xor m1
        p(i + 1)? = p(i + 1)? xor m2
        p(i + 2)? = p(i + 2)? xor m3
        p(i + 3)? = p(i + 3)? xor m4
        i = i + 4
      end
      while i < size do
        p(i)? = p(i)? xor mask_key(i % 4)?
        i = i + 1
      end
    end
    p
