local M6502 = {}

function M6502.Z6502State() return {pc = 0, s = 0, p = 0, a = 0, x = 0, y = 0, internal = {irq = true, nmi = true}} end
function M6502.new() return setmetatable({cycles = 0, context = {}, read = function(self, address) error("M6502.read: not implemented") end, write = function(self, address, value) error("M6502.write: not implemented") end, state = M6502.Z6502State(), opcode = 0, ea_cycles = 0, ea = 0}, {__index = M6502}) end
local function l1(num) return bit32.lshift(num, 8) end  -- num << 8
local function l2(num) return bit32.lshift(num, 16) end -- num << 16
local function l3(num) return bit32.lshift(num, 24) end -- num << 24
local function l4(num) return bit32.lshift(num, 32) end -- num << 32
local function r1(num) return bit32.rshift(num, 8) end  -- num >> 8
local function r2(num) return bit32.rshift(num, 16) end -- num >> 16
local function r3(num) return bit32.rshift(num, 24) end -- num >> 24
local function r4(num) return bit32.rshift(num, 32) end -- num >> 32
local l8 = l1
local l16 = l2
local l24 = l3
local l32 = l4
local r8 = r1
local r16 = r2
local r24 = r3
local r32 = r4
local function zuint8(num) return bit32.band(num, 0xFF) end
local function zuint16(num) return bit32.band(num, 0xFFFF) end
local function zuint32(num) return bit32.band(num, 0xFFFFFFFF) end
local zuint = zuint32
local function sign(num, bits) return bit32.btest(num, 2^(bits-1)) and num - 2^bits or num end

local function read_16bit(object, address)
    return zuint16(bit32.bor(
        object:read(
            zuint16(address)
        ), l8(object:read(
            zuint16(address + 1)
        ))
    ))
end

local function push_16bit(object, value)
    object:write(
        zuint16(bit32.bor(0x0100, object.state.s)),
        zuint8(r8(value))
    )
    object:write(
        zuint16(bit32.bor(
            0x0100,
            zuint8(object.state.s - 1)
        )),
        zuint8(value)
    )
    object.state.s = zuint8(object.state.s - 2)
end

local function pop_16bit(object)
    local result = zuint16(
        bit32.bor(
            object:read(
                zuint16(
                    bit32.bor(
                        0x0100,
                        zuint8(object.state.s + 1)
                    )
                )
            ),
            l8(
                zuint16(object:read(
                    zuint16(bit32.bor(
                        0x0100,
                        zuint8(object.state.s + 2)
                    ))
                ))
            )
        )
    )
    object.state.s = zuint8(object.state.s + 2)
    return result
end

local function read_accumulator(object)
    object.ea_cycles = 2
    object.state.pc = object.state.pc + 1
    return object.state.a
end

local function read_immediate(object) 
    object.ea_cycles = 2
    object.state.pc = object.state.pc + 2
    return object:read(zuint16(object.state.pc - 1))
end

local function read_zero_page(object)
    object.ea_cycles = 3
    object.state.pc = object.state.pc + 2
    return object:read(zuint16(object:read(zuint16(object.state.pc - 1))))
end

local function read_zero_page_x(object) 
    object.ea_cycles = 4
    object.state.pc = object.state.pc + 2
    return object:read(
        zuint8(
            object:read(
                zuint16(
                    object.state.pc - 1
                )
            ) + object.state.x
        )
    )
end

local function read_zero_page_y(object) 
    object.ea_cycles = 4
    object.state.pc = object.state.pc + 2
    return object:read(
        zuint8(
            object:read(
                zuint16(
                    object.state.pc - 1
                )
            ) + object.state.y
        )
    )
end

local function read_absolute(object)
    object.ea_cycles = 4
    object.state.pc = object.state.pc + 3
    return object:read(
        read_16bit(
            object,
            zuint16(object.state.pc - 2)
        )
    )
end

local function read_indirect_x(object)
    object.ea_cycles = 6
    object.state.pc = object.state.pc + 2
    return object:read(
        read_16bit(
            object,
            zuint8(
                object:read(zuint16(object.state.pc - 1)) + object.state.x
            )
        )
    )
end

local function read_g_zero_page(object)
    object.ea_cycles = 5
    object.state.pc = object.state.pc + 2
    object.ea = object:read(
        zuint16(object.state.pc - 1)
    )
    return object:read(
        zuint16(object.ea)
    )
end

local function read_g_zero_page_x(object)
    object.ea_cycles = 6
    object.state.pc = object.state.pc + 2
    object.ea = zuint8(
        object:read(
            zuint16(object.state.pc - 1)
        ) + object.state.x
    )
    return object:read(
        zuint16(object.ea)
    )
end

local function read_g_absolute(object)
    object.ea_cycles = 6
    object.state.pc = object.state.pc + 3
    object.ea = read_16bit(object, zuint16(object.state.pc - 2))
    return object:read(object.ea)
end

local function read_g_absolute_x(object)
    object.ea_cycles = 7
    object.state.pc = object.state.pc + 3
    object.ea = zuint16(read_16bit(object, zuint16(object.state.pc - 2)) + object.state.x)
    return object:read(object.ea)
end

local function read_penalized_absolute_x(object)
    object.state.pc = object.state.pc + 3
    local address = read_16bit(object, zuint16(object.state.pc - 2))
    object.ea_cycles = (zuint8(address) + object.state.x > 255 and 5 or 4)
    return object:read(zuint16(address + object.state.x))
end

local function read_penalized_absolute_y(object)
    object.state.pc = object.state.pc + 3
    local address = read_16bit(object, zuint16(object.state.pc - 2))
    object.ea_cycles = (zuint8(address) + object.state.y > 255 and 5 or 4)
    return object:read(zuint16(address + object.state.y))
end

local function read_penalized_indirect_y(object)
    object.state.pc = object.state.pc + 2
    local address = read_16bit(
        object,
        zuint16(
            object:read(
                zuint16(
                    object.state.pc - 1
                )
            )
        )
    )
    object.ea_cycles = zuint8(address) + (object.state.y > 255 and 6 or 5)
    return object:read(zuint16(address + object.state.y))
end

local function write_zero_page(object, value)
    object.ea_cycles = 3
    object.state.pc = object.state.pc + 2
    object:write(
        zuint16(
            object:read(
                zuint16(
                    object.state.pc - 1
                )
            )
        ),
        zuint8(value)
    )
end

local function write_zero_page_x(object, value)
    object.ea_cycles = 4
    object.state.pc = object.state.pc + 2
    object:write(
        zuint8(
            object:read(
                zuint16(
                    object.state.pc - 1
                )
            ) + object.state.x
        ),
        zuint8(value)
    )
end

local function write_zero_page_y(object, value)
    object.ea_cycles = 4
    object.state.pc = object.state.pc + 2
    object:write(
        zuint8(
            object:read(
                zuint16(
                    object.state.pc - 1
                )
            ) + object.state.y
        ),
        zuint8(value)
    )
end

local function write_absolute(object, value)
    object.ea_cycles = 4
    object.state.pc = object.state.pc + 3
    object:write(
        read_16bit(
            object,
            zuint16(
                object.state.pc - 2
            )
        ),
        zuint8(value)
    )
end

local function write_absolute_x(object, value)
    object.ea_cycles = 5
    object.state.pc = object.state.pc + 3
    object:write(
        zuint16(
            read_16bit(
                object,
                zuint16(
                    object.state.pc - 2
                )
            ) + object.state.x
        ),
        zuint8(value)
    )
end

local function write_absolute_y(object, value)
    object.ea_cycles = 5
    object.state.pc = object.state.pc + 3
    object:write(
        zuint16(
            read_16bit(
                object,
                zuint16(
                    object.state.pc - 2
                )
            ) + object.state.y
        ),
        zuint8(value)
    )
end

local function write_indirect_x(object, value)
    object.ea_cycles = 6
    object.state.pc = object.state.pc + 2
    object:write(
        zuint16(
            read_16bit(
                object,
                zuint8(
                    object:read(zuint16(object.state.pc - 1)) + object.state.x
                )
            )
        ),
        zuint8(value)
    )
end

local function write_indirect_y(object, value)
    object.ea_cycles = 6
    object.state.pc = object.state.pc + 2
    object:write(
        zuint16(
            read_16bit(
                object,
                zuint16(
                    object:read(
                        zuint16(
                            object.state.pc - 1
                        )
                    )
                )
            ) + object.state.y
        ),
        zuint8(value)
    )
end

local read_j_table = {
    [ 0 ] = read_indirect_x,
    read_zero_page,
    read_immediate,
    read_absolute,
    read_penalized_indirect_y,
    read_zero_page_x,
    read_penalized_absolute_y,
    read_penalized_absolute_x
}

local write_k_table = {
    [ 0 ] = write_indirect_x,
    write_zero_page,
    error,
    write_absolute,
    write_indirect_y,
    write_zero_page_x,
    write_absolute_y,
    write_absolute_x
}

local read_g_table = {
    [ 0 ] = error,
    read_g_zero_page,
    read_accumulator,
    read_g_absolute,
    error,
    read_g_zero_page_x,
    error,
    read_g_absolute_x
}

local read_h_table = {
    [ 0 ] = read_immediate,
    read_zero_page,
    error,
    read_absolute,
    error,
    read_zero_page_y,
    error,
    read_penalized_absolute_y
}

local write_h_table = {
    [ 0 ] = error,
    write_zero_page,
    error,
    write_absolute,
    error,
    write_zero_page_y
}

local read_q_table = {
    [ 0 ] = read_immediate,
    read_zero_page,
    error,
    read_absolute,
    error,
    read_zero_page_x,
    error,
    read_penalized_absolute_x
}

local write_q_table = {
    [ 0 ] = error,
    write_zero_page,
    error,
    write_absolute,
    error,
    write_zero_page_x
}

-- Convenience functions
local function frombool(b) if b then return 1 else return 0 end end
local function tobool(num) return num ~= 0 end
local function and28r2(num) return bit32.rshift(bit32.band(num, 28), 2) end
local function andnot130(num) return bit32.band(num, zuint8(bit32.bnot(130))) end
local function and128else2(num) return tobool(num) and bit32.band(num, 128) or 2 end
local function setp(p, num) return bit32.bor(andnot130(p), and128else2(num)) end
local function not8(num) return zuint8(bit32.bnot(num)) end

local function lda_J(object)
    object.state.a = zuint8(read_j_table[and28r2(object.opcode)](object))
    object.state.p = setp(object.state.p, object.state.a)
    return object.ea_cycles
end

local function ldx_H(object)
    object.state.x = zuint8(read_h_table[and28r2(object.opcode)](object))
    object.state.p = setp(object.state.p, object.state.x)
    return object.ea_cycles
end

local function ldy_Q(object)
    object.state.y = zuint8(read_q_table[and28r2(object.opcode)](object))
    object.state.p = setp(object.state.p, object.state.y)
    return object.ea_cycles
end

local function sta_K(object)
    write_k_table[and28r2(object.opcode)](object, object.state.a)
    return object.ea_cycles
end

local function stx_H(object)
    write_h_table[and28r2(object.opcode)](object, object.state.x)
    return object.ea_cycles
end

local function sty_Q(object)
    write_q_table[and28r2(object.opcode)](object, object.state.y)
    return object.ea_cycles
end

local function tax(object)
    object.state.pc = object.state.pc + 1
    object.state.x = object.state.a
    object.state.p = setp(object.state.p, object.state.x)
    return 2
end

local function tay(object)
    object.state.pc = object.state.pc + 1
    object.state.y = object.state.a
    object.state.p = setp(object.state.p, object.state.y)
    return 2
end

local function txa(object)
    object.state.pc = object.state.pc + 1
    object.state.a = object.state.x
    object.state.p = setp(object.state.p, object.state.a)
    return 2
end

local function tya(object)
    object.state.pc = object.state.pc + 1
    object.state.a = object.state.y
    object.state.p = setp(object.state.p, object.state.a)
    return 2
end

local function tsx(object)
    object.state.pc = object.state.pc + 1
    object.state.x = object.state.s
    object.state.p = setp(object.state.p, object.state.x)
    return 2
end

local function txs(object)
    object.state.pc = object.state.pc + 1
    object.state.s = object.state.x
    return 2
end

local function pha(object)
    object.state.pc = object.state.pc + 1
    object:write(zuint16(0x0100 + object.state.s), zuint8(object.state.a))
    object.state.s = zuint8(object.state.s - 1)
    return 3
end

local function php(object)
    object.state.pc = object.state.pc + 1
    object:write(zuint16(0x0100 + object.state.s), zuint8(bit32.bor(object.state.p, 0x30)))
    object.state.s = zuint8(object.state.s - 1)
    return 3
end

local function pla(object)
    object.state.pc = object.state.pc + 1
    object.state.s = zuint8(object.state.s + 1)
    object.state.a = object:read(zuint16(0x0100 + object.state.s))
    object.state.p = setp(object.state.p, object.state.a)
    return 4
end

local function plp(object)
    object.state.pc = object.state.pc + 1
    object.state.s = zuint8(object.state.s + 1)
    object.state.p = object:read(zuint16(0x0100 + object.state.s))
    return 4
end

local function and_J(object)
    object.state.a = bit32.band(object.state.a, read_j_table[and28r2(object.opcode)](object))
    object.state.p = setp(object.state.p, object.state.a)
    return object.ea_cycles
end

local function eor_J(object)
    object.state.a = zuint8(bit32.bxor(object.state.a, read_j_table[and28r2(object.opcode)](object)))
    object.state.p = setp(object.state.p, object.state.a)
    return object.ea_cycles
end

local function ora_J(object)
    object.state.a = bit32.bor(object.state.a, read_j_table[and28r2(object.opcode)](object))
    object.state.p = setp(object.state.p, object.state.a)
    return object.ea_cycles
end

local function bit_Q(object)
    local v = read_q_table[and28r2(object.opcode)](object)
    object.state.p = bit32.bor(bit32.band(object.state.p, not8(194)), bit32.band(v, 192))
    if not bit32.btest(v, object.state.a) then object.state.p = bit32.bor(object.state.p, 2) end
    return object.ea_cycles
end

local function cmp_J(object)
    local v = read_j_table[and28r2(object.opcode)](object)
    local result = object.state.a - v
    object.state.p = zuint8(bit32.bor(bit32.band(object.state.p, not8(131)), bit32.bor(bit32.band(result, 128), bit32.bor(bit32.lshift(frombool(not tobool(result)), 1), frombool(object.state.a >= v)))))
    return object.ea_cycles
end

local function cpx_Q(object)
    local v = read_q_table[and28r2(object.opcode)](object)
    local result = object.state.x - v
    object.state.p = zuint8(bit32.bor(bit32.band(object.state.p, not8(131)), bit32.bor(bit32.band(result, 128), bit32.bor(bit32.lshift(frombool(not tobool(result)), 1), frombool(object.state.x >= v)))))
    return object.ea_cycles
end

local function cpy_Q(object)
    local v = read_q_table[and28r2(object.opcode)](object)
    local result = object.state.y - v
    object.state.p = zuint8(bit32.bor(bit32.band(object.state.p, not8(131)), bit32.bor(bit32.band(result, 128), bit32.bor(bit32.lshift(frombool(not tobool(result)), 1), frombool(object.state.y >= v)))))
    return object.ea_cycles
end

local function adc_J(object)
    local v = read_j_table[and28r2(object.opcode)](object)
    local c = bit32.band(object.state.p, 1)

    if bit32.btest(object.state.p, 8) then
        local l = zuint(bit32.band(object.state.a, 0x0F)) + bit32.band(v, 0x0F) + c
        local h = zuint(bit32.band(object.state.a, 0xF0)) + bit32.band(v, 0xF0)

        object.state.p = bit32.band(object.state.p, not8(195))

        if not bit32.btest(l + h, 0xFF) then object.state.p = bit32.bor(object.state.p, 2) end
        if l > 9 then
            h = h + 16
            l = l + 6
        end
        if bit32.btest(h, 0x80) then object.state.p = bit32.bor(object.state.p, 128) end
        if bit32.btest(bit32.bnot(bit32.bxor(object.state.a, v)), bit32.band(bit32.bxor(object.state.a, h), 0x80)) then object.state.p = bit32.band(object.state.p, 64) end
        if h > 0x90 then h = h + 0x60 end
        if tobool(bit32.rshift(h, 8)) then object.state.p = bit32.bor(object.state.p, 1) end

        object.state.a = bit32.bor(bit32.band(l, 0x0F), bit32.band(h, 0xF0))
    else
        local t = zuint(object.state.a) + v + c

        object.state.p = bit32.band(object.state.p, not8(65))

        if bit32.btest(bit32.bnot(bit32.bxor(object.state.a, v)), bit32.band(bit32.bxor(object.state.a, t), 0x80)) then object.state.p = bit32.bor(object.state.p, 64) end
        if tobool(bit32.rshift(t, 8)) then object.state.p = bit32.bor(object.state.p, 1) end

        object.state.a = zuint8(t)
        object.state.p = setp(object.state.p, object.state.a)
    end

    return object.ea_cycles
end

local function sbc_J(object)
    local v = read_j_table[and28r2(object.opcode)](object)
    local c = frombool(not bit32.btest(object.state.p, 1))
    local t = object.state.a - v - c

    if bit32.btest(object.state.p, 8) then
        local l = zuint(bit32.band(object.state.a, 0x0F)) + bit32.band(v, 0x0F) + c
        local h = zuint(bit32.band(object.state.a, 0xF0)) + bit32.band(v, 0xF0)

        object.state.p = bit32.band(object.state.p, not8(195))

        if bit32.btest(l, 0x10) then
            l = l - 6
            h = h - 1
        end
        if bit32.btest(bit32.bxor(object.state.a, v), bit32.band(bit32.bxor(object.state.a, t), 0x80)) then object.state.p = bit32.bor(object.state.p, 64) end
        if not tobool(bit32.rshift(t, 8)) then object.state.p = bit32.bor(object.state.p, 1) end
        if not tobool(bit32.lshift(t, 8)) then object.state.p = bit32.bor(object.state.p, 2) end
        if bit32.btest(t, 0x80) then object.state.p = bit32.bor(object.state.p, 128) end
        if bit32.btest(h, 0x0100) then h = h - 0x60 end

        object.state.a = bit32.bor(bit32.band(l, 0x0F), bit32.band(h, 0xF0))
    else
        object.state.p = bit32.band(object.state.p, 0x3C)

        if t < -128 then object.state.p = bit32.bor(object.state.p, 64) end
        if t >= 0 then object.state.p = bit32.bor(object.state.p, 1) end

        object.state.a = zuint8(t)
        object.state.p = setp(object.state.p, object.state.a)
    end

    return object.ea_cycles
end

local function inc_G(object)
    local t = zuint8(read_g_table[and28r2(object.opcode)](object) + 1)
    if object.ea_cycles == 2 then object.state.a = t
    else object:write(zuint16(object.ea), zuint8(t)) end
    object.state.p = setp(object.state.p, t)
    return object.ea_cycles
end

local function inx(object)
    object.state.pc = object.state.pc + 1
    object.state.x = zuint8(object.state.x + 1)
    object.state.p = setp(object.state.p, object.state.x)
    return 2
end

local function iny(object)
    object.state.pc = object.state.pc + 1
    object.state.y = zuint8(object.state.y + 1)
    object.state.p = setp(object.state.p, object.state.y)
    return 2
end

local function dec_G(object)
    local t = zuint8(read_g_table[and28r2(object.opcode)](object) - 1)
    if object.ea_cycles == 2 then object.state.a = t
    else object:write(zuint16(object.ea), zuint8(t)) end
    object.state.p = setp(object.state.p, t)
    return object.ea_cycles
end

local function dex(object)
    object.state.pc = object.state.pc + 1
    object.state.x = zuint8(object.state.x - 1)
    object.state.p = setp(object.state.p, object.state.x)
    return 2
end

local function dey(object)
    object.state.pc = object.state.pc + 1
    object.state.y = zuint8(object.state.y - 1)
    object.state.p = setp(object.state.p, object.state.y)
    return 2
end

local function asl_G(object)
    local v = read_g_table[and28r2(object.opcode)](object)
    local t = zuint8(v * 2)

    if object.ea_cycles == 2 then object.state.a = t
    else object:write(zuint16(object.ea), t) end
    object.state.p = zuint8(bit32.bor(bit32.band(object.state.p, not8(131)), bit32.bor(bit32.band(t, 128), bit32.bor(bit32.lshift(frombool(not tobool(t)), 1), bit32.rshift(v, 7)))))
    return object.ea_cycles
end

local function lsr_G(object)
    local v = read_g_table[and28r2(object.opcode)](object)
    local t = bit32.rshift(v, 1)

    if object.ea_cycles == 2 then object.state.a = t
    else object:write(zuint16(object.ea), zuint8(t)) end
    object.state.p = zuint8(bit32.bor(bit32.band(object.state.p, not8(131)), bit32.bor(bit32.lshift(frombool(not tobool(t)), 1), bit32.band(v, 1))))
    return object.ea_cycles
end

local function rol_G(object)
    local v = read_g_table[and28r2(object.opcode)](object)
    local t = zuint8(bit32.bor(bit32.lshift(v, 1), bit32.band(object.state.p, 1)))

    if object.ea_cycles == 2 then object.state.a = t
    else object:write(zuint16(object.ea), zuint8(t)) end
    object.state.p = zuint8(bit32.bor(bit32.band(object.state.p, not8(131)), bit32.bor(bit32.band(t, 128), bit32.bor(bit32.lshift(frombool(not tobool(t)), 1), bit32.rshift(v, 7)))))
    return object.ea_cycles
end

local function ror_G(object)
    local v = read_g_table[and28r2(object.opcode)](object)
    local t = zuint8(bit32.bor(bit32.rshift(v, 1), bit32.lshift(bit32.band(object.state.p, 1), 7)))

    if object.ea_cycles == 2 then object.state.a = t
    else object:write(zuint16(object.ea), zuint8(t)) end
    object.state.p = zuint8(bit32.bor(bit32.band(object.state.p, not8(131)), bit32.bor(bit32.band(t, 128), bit32.bor(bit32.lshift(frombool(not tobool(t)), 1), bit32.band(v, 1)))))
    return object.ea_cycles
end

local function jmp_WORD(object)
    object.state.pc = read_16bit(object, zuint16(object.state.pc + 1))
    return 3
end

local function jmp_vWORD(object)
    object.state.pc = read_16bit(object, zuint16(read_16bit(object, zuint16(object.state.pc + 1))))
    return 5
end

local function jsr_WORD(object)
    push_16bit(object, object.state.pc + 2)
    object.state.pc = read_16bit(object, zuint16(object.state.pc + 1))
    --print("Jumping to " .. object.state.pc)
    return 6
end

local function rts(object)
    object.state.pc = pop_16bit(object) + 1
    --print("Returning to " .. tostring(object.state.pc))
    return 6
end

local function bcc_OFFSET(object)
    local cycles = 2
    if not bit32.btest(object.state.p, 1) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function bcs_OFFSET(object)
    local cycles = 2
    if bit32.btest(object.state.p, 1) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function beq_OFFSET(object)
    local cycles = 2
    if bit32.btest(object.state.p, 2) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function bmi_OFFSET(object)
    local cycles = 2
    if bit32.btest(object.state.p, 128) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function bne_OFFSET(object)
    local cycles = 2
    if not bit32.btest(object.state.p, 2) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function bpl_OFFSET(object)
    local cycles = 2
    if not bit32.btest(object.state.p, 128) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function bvc_OFFSET(object)
    local cycles = 2
    if not bit32.btest(object.state.p, 64) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function bvs_OFFSET(object)
    local cycles = 2
    if bit32.btest(object.state.p, 64) then
        local pc = object.state.pc + 2
        local offset = sign(object:read(zuint16(object.state.pc + 1)), 8)
        local t = zuint16(pc + offset)
        if bit32.rshift(t, 8) == bit32.rshift(pc, 8) then cycles = cycles + 1
        else cycles = cycles + 2 end
        object.state.pc = t
    else object.state.pc = object.state.pc + 2 end
    return cycles
end

local function clc(object)
    object.state.pc = object.state.pc + 1
    object.state.p = bit32.band(object.state.p, not8(1))
    return 2
end

local function cld(object)
    object.state.pc = object.state.pc + 1
    object.state.p = bit32.band(object.state.p, not8(8))
    return 2
end

local function cli(object)
    object.state.pc = object.state.pc + 1
    object.state.p = bit32.band(object.state.p, not8(4))
    return 2
end

local function clv(object)
    object.state.pc = object.state.pc + 1
    object.state.p = bit32.band(object.state.p, not8(64))
    return 2
end

local function sec(object)
    object.state.pc = object.state.pc + 1
    object.state.p = bit32.bor(object.state.p, 1)
    return 2
end

local function sed(object)
    object.state.pc = object.state.pc + 1
    object.state.p = bit32.bor(object.state.p, 8)
    return 2
end

local function sei(object)
    object.state.pc = object.state.pc + 1
    object.state.p = bit32.bor(object.state.p, 4)
    return 2
end

local function nop(object)
    object.state.pc = object.state.pc + 1
    return 2
end

local function rti(object)
    object.state.s = zuint8(object.state.s + 1)
    object.state.p = object:read(zuint16(0x0100 + object.state.s))
    object.state.pc = pop_16bit(object)
    return 6
end

local function brk(object)
    print("Hit breakpoint")
    --exit()
    --object:read(zuint16(object.state.pc + 1))
    object.state.p = bit32.bor(object.state.p, 0x30)
    push_16bit(object, object.state.pc + 2)
    object:write(zuint16(0x0100 + object.state.s), zuint8(object.state.p))
    object.state.p = bit32.bor(object.state.p, 0x04)
    object.state.s = zuint8(object.state.s - 1)
    object.state.pc = read_16bit(object, 0xFFFE)
    return 7
end

local function illegal(object)
    error("Illegal instruction: " .. object.opcode .. " (at " .. object.state.pc .. ")")
end

local instruction_table = {
    [ 0 ] = brk,
    ora_J,
    illegal,
    illegal,
    illegal,
    ora_J,
    asl_G,
    illegal,
    php,
    ora_J,
    asl_G,
    illegal,
    illegal,
    ora_J,
    asl_G,
    illegal,
    bpl_OFFSET,
    ora_J,
    illegal,
    illegal,
    illegal,
    ora_J,
    asl_G,
    illegal,
    clc,
    ora_J,
    illegal,
    illegal,
    illegal,
    ora_J,
    asl_G,
    illegal,
    jsr_WORD,
    and_J,
    illegal,
    illegal,
    bit_Q,
    and_J,
    rol_G,
    illegal,
    plp,
    and_J,
    rol_G,
    illegal,
    bit_Q,
    and_J,
    rol_G,
    illegal,
    bmi_OFFSET,
    and_J,
    illegal,
    illegal,
    illegal,
    and_J,
    rol_G,
    illegal,
    sec,
    and_J,
    illegal,
    illegal,
    illegal,
    and_J,
    rol_G,
    illegal,
    rti,
    eor_J,
    illegal,
    illegal,
    illegal,
    eor_J,
    lsr_G,
    illegal,
    pha,
    eor_J,
    lsr_G,
    illegal,
    jmp_WORD,
    eor_J,
    lsr_G,
    illegal,
    bvc_OFFSET,
    eor_J,
    illegal,
    illegal,
    illegal,
    eor_J,
    lsr_G,
    illegal,
    cli,
    eor_J,
    illegal,
    illegal,
    illegal,
    eor_J,
    lsr_G,
    illegal,
    rts,
    adc_J,
    illegal,
    illegal,
    illegal,
    adc_J,
    ror_G,
    illegal,
    pla,
    adc_J,
    ror_G,
    illegal,
    jmp_vWORD,
    adc_J,
    ror_G,
    illegal,
    bvs_OFFSET,
    adc_J,
    illegal,
    illegal,
    illegal,
    adc_J,
    ror_G,
    illegal,
    sei,
    adc_J,
    illegal,
    illegal,
    illegal,
    adc_J,
    ror_G,
    illegal,
    illegal,
    sta_K,
    illegal,
    illegal,
    sty_Q,
    sta_K,
    stx_H,
    illegal,
    dey,
    illegal,
    txa,
    illegal,
    sty_Q,
    sta_K,
    stx_H,
    illegal,
    bcc_OFFSET,
    sta_K,
    illegal,
    illegal,
    sty_Q,
    sta_K,
    stx_H,
    illegal,
    tya,
    sta_K,
    txs,
    illegal,
    illegal,
    sta_K,
    illegal,
    illegal,
    ldy_Q,
    lda_J,
    ldx_H,
    illegal,
    ldy_Q,
    lda_J,
    ldx_H,
    illegal,
    tay,
    lda_J,
    tax,
    illegal,
    ldy_Q,
    lda_J,
    ldx_H,
    illegal,
    bcs_OFFSET,
    lda_J,
    illegal,
    illegal,
    ldy_Q,
    lda_J,
    ldx_H,
    illegal,
    clv,
    lda_J,
    tsx,
    illegal,
    ldy_Q,
    lda_J,
    ldx_H,
    illegal,
    cpy_Q,
    cmp_J,
    illegal,
    illegal,
    cpy_Q,
    cmp_J,
    dec_G,
    illegal,
    iny,
    cmp_J,
    dex,
    illegal,
    cpy_Q,
    cmp_J,
    dec_G,
    illegal,
    bne_OFFSET,
    cmp_J,
    illegal,
    illegal,
    illegal,
    cmp_J,
    dec_G,
    illegal,
    cld,
    cmp_J,
    illegal,
    illegal,
    illegal,
    cmp_J,
    dec_G,
    illegal,
    cpx_Q,
    sbc_J,
    illegal,
    illegal,
    cpx_Q,
    sbc_J,
    inc_G,
    illegal,
    inx,
    sbc_J,
    nop,
    illegal,
    cpx_Q,
    sbc_J,
    inc_G,
    illegal,
    beq_OFFSET,
    sbc_J,
    illegal,
    illegal,
    illegal,
    sbc_J,
    inc_G,
    illegal,
    sed,
    sbc_J,
    illegal,
    illegal,
    illegal,
    sbc_J,
    inc_G,
    illegal
}

function M6502.power(object, state)
    if state then
        object.state.s = 0xFD
        object.state.p = 0x36
    else
        object.state.s = 0
        object.state.p = 0
    end
    object.state.pc = 0x0000
    object.state.a = 0x00
    object.state.x = 0x00
    object.state.y = 0x00
    object.state.internal.irq = false
    object.state.internal.nmi = false
end

function M6502.reset(object)
    object.state.pc = read_16bit(object, 0xFFFC)
    object.state.s = 0xFD
    object.state.p = 0x36
    object.state.internal.irq = false
    object.state.internal.nmi = false
end

function M6502.nmi(object)
    object.state.internal.nmi = true
end

function M6502.irq(object, state)
    object.state.internal.irq = state
end

local function nilprotect(v) if v == nil then error("Illegal instruction") else return v end end

function M6502.run(object, cycles)
    object.cycles = 0

    while (object.cycles < cycles) do
        if object.state.internal.nmi then
            print("Got NMI")
            object.state.internal.nmi = false
            object.state.p = bit32.band(object.state.p, not8(16))
            push_16bit(object, object.state.pc)
            object.state.s = zuint8(object.state.s - 1)
            object:write(zuint16(0x0100 + object.state.s - 1), zuint8(object.state.p))
            object.state.pc = read_16bit(object, 0xFFFA)
            object.state.p = bit32.bor(object.state.p, 4)
            object.cycles = object.cycles + 7
        elseif object.state.internal.irq and not bit32.btest(object.state.p, 4) then
            print("Got IRQ")
            object.state.p = bit32.band(object.state.p, not8(16))
            push_16bit(object, object.state.pc)
            object.state.s = zuint8(object.state.s - 1)
            object:write(zuint16(0x0100 + object.state.s - 1), zuint8(object.state.p))
            object.state.pc = read_16bit(object, 0xFFFA)
            object.state.p = bit32.bor(object.state.p, 4)
            object.cycles = object.cycles + 7
        else
            object.opcode = object:read(zuint16(object.state.pc))
            local pc = object.state.pc
            --print(("Running opcode %02X at %04X"):format(object.opcode, object.state.pc))
            object.cycles = object.cycles + nilprotect(instruction_table[object.opcode])(object)
            if pc == object.state.pc then return -1 end
        end
    end

    return object.cycles
end

function M6502.call(object, address, maxcycles)
    object.cycles = 0
    local oldaddr = object.state.pc
    push_16bit(object, oldaddr)
    object.state.pc = address

    while object.state.pc ~= oldaddr + 1 do
        if maxcycles and object.cycles > maxcycles then error("Call cycle count exceeded", 2) end
        if object.state.internal.nmi then
            print("Got NMI")
            object.state.internal.nmi = false
            object.state.p = bit32.band(object.state.p, not8(16))
            push_16bit(object, object.state.pc)
            object.state.s = zuint8(object.state.s - 1)
            object:write(zuint16(0x0100 + object.state.s - 1), zuint8(object.state.p))
            object.state.pc = read_16bit(object, 0xFFFA)
            object.state.p = bit32.bor(object.state.p, 4)
            object.cycles = object.cycles + 7
        elseif object.state.internal.irq and not bit32.btest(object.state.p, 4) then
            print("Got IRQ")
            object.state.p = bit32.band(object.state.p, not8(16))
            push_16bit(object, object.state.pc)
            object.state.s = zuint8(object.state.s - 1)
            object:write(zuint16(0x0100 + object.state.s - 1), zuint8(object.state.p))
            object.state.pc = read_16bit(object, 0xFFFA)
            object.state.p = bit32.bor(object.state.p, 4)
            object.cycles = object.cycles + 7
        else
            object.opcode = object:read(zuint16(object.state.pc))
            --print("Running opcode " .. tostring(object.opcode) .. " at " .. object.state.pc)
            object.cycles = object.cycles + nilprotect(instruction_table[object.opcode])(object)
        end
    end

    return object.cycles
end

return M6502