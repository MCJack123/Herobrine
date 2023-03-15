-------------------------------------------------------------------------------
--  This file is reSID, a MOS6581 SID emulator engine, ported to Lua.
--  Copyright (C) 2004  Dag Lem <resid@nimrod.no>
--  Lua port Copyright (C) 2023  JackMacWindows
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-------------------------------------------------------------------------------

local band, bor, bxor, bnot, btest, lshift, rshift = bit32.band, bit32.bor, bit32.bxor, bit32.bnot, bit32.btest, bit32.lshift, bit32.rshift
local floor, min, max, pi, log, ceil, abs, sqrt, sin = math.floor, math.min, math.max, math.pi, math.log, math.ceil, math.abs, math.sqrt, math.sin

local function arshift(a, s)
    return floor(a / 2^s)
end

-- * siddefs *

local chip_model = {
    MOS6581 = 0,
    MOS8580 = 1
}

local sampling_method = {
    SAMPLE_FAST = 0,
    SAMPLE_INTERPOLATE = 1,
    SAMPLE_RESAMPLE_INTERPOLATE = 2,
    SAMPLE_RESAMPLE_FAST = 3
}

-- * envelope *

local EnvelopeGenerator = {}
EnvelopeGenerator.__index = EnvelopeGenerator

EnvelopeGenerator.State = {
    ATTACK = 0,
    DECAY_SUSTAIN = 1,
    RELEASE = 2
}

function EnvelopeGenerator:new()
    local obj = setmetatable({}, self)
    obj:reset()
    return obj
end

function EnvelopeGenerator:reset()
    self.envelope_counter = 0

    self.attack = 0
    self.decay = 0
    self.sustain = 0
    self.release = 0

    self.gate = 0

    self.rate_counter = 0
    self.exponential_counter = 0
    self.exponential_counter_period = 1

    self.state = EnvelopeGenerator.State.RELEASE
    self.rate_period = EnvelopeGenerator.rate_counter_period[self.release]
    self.hold_zero = true
end

EnvelopeGenerator.rate_counter_period = {
  [0] = 9,  --   2ms*1.0MHz/256 =     7.81
       32,  --   8ms*1.0MHz/256 =    31.25
       63,  --  16ms*1.0MHz/256 =    62.50
       95,  --  24ms*1.0MHz/256 =    93.75
      149,  --  38ms*1.0MHz/256 =   148.44
      220,  --  56ms*1.0MHz/256 =   218.75
      267,  --  68ms*1.0MHz/256 =   265.63
      313,  --  80ms*1.0MHz/256 =   312.50
      392,  -- 100ms*1.0MHz/256 =   390.63
      977,  -- 250ms*1.0MHz/256 =   976.56
     1954,  -- 500ms*1.0MHz/256 =  1953.13
     3126,  -- 800ms*1.0MHz/256 =  3125.00
     3907,  --   1 s*1.0MHz/256 =  3906.25
    11720,  --   3 s*1.0MHz/256 = 11718.75
    19532,  --   5 s*1.0MHz/256 = 19531.25
    31251   --   8 s*1.0MHz/256 = 31250.00
}

EnvelopeGenerator.sustain_level = {
    [0] = 0x00,
    0x11,
    0x22,
    0x33,
    0x44,
    0x55,
    0x66,
    0x77,
    0x88,
    0x99,
    0xaa,
    0xbb,
    0xcc,
    0xdd,
    0xee,
    0xff,
}

function EnvelopeGenerator:writeCONTROL_REG(control)
    local gate_next = btest(control, 0x01)

    if not self.gate and gate_next then
        self.state = EnvelopeGenerator.State.ATTACK
        self.rate_period = EnvelopeGenerator.rate_counter_period[self.attack]

        self.hold_zero = false
    elseif self.gate and not gate_next then
        self.state = EnvelopeGenerator.State.RELEASE
        self.rate_period = EnvelopeGenerator.rate_counter_period[self.release]
    end

    self.gate = gate_next
end

function EnvelopeGenerator:writeATTACK_DECAY(attack_decay)
    self.attack = band(rshift(attack_decay, 4), 0x0f)
    self.decay = band(attack_decay, 0x0f)
    if self.state == EnvelopeGenerator.State.ATTACK then
        self.rate_period = EnvelopeGenerator.rate_counter_period[self.attack]
    elseif self.state == EnvelopeGenerator.State.DECAY_SUSTAIN then
        self.rate_period = EnvelopeGenerator.rate_counter_period[self.decay]
    end
end

function EnvelopeGenerator:writeSUSTAIN_RELEASE(sustain_release)
    self.sustain = band(rshift(sustain_release, 4), 0x0f)
    self.release = band(sustain_release, 0x0f)
    if self.state == EnvelopeGenerator.State.RELEASE then
        self.rate_period = EnvelopeGenerator.rate_counter_period[self.release]
    end
end

function EnvelopeGenerator:readENV()
    return self:output()
end

function EnvelopeGenerator:_inc_exponential_counter() self.exponential_counter = self.exponential_counter + 1 return self.exponential_counter end

function EnvelopeGenerator:clock_0()
    self.rate_counter = self.rate_counter + 1
    if self.rate_counter >= 0x8000 then
        self.rate_counter = band(self.rate_counter + 1, 0x7fff)
    end

    if self.rate_counter ~= self.rate_period then
        return
    end

    self.rate_counter = 0

    if self.state == EnvelopeGenerator.State.ATTACK or self:_inc_exponential_counter() == self.exponential_counter_period then
        self.exponential_counter = 0

        if self.hold_zero then
            return
        end

        if self.state == EnvelopeGenerator.State.ATTACK then
            self.envelope_counter = band(self.envelope_counter + 1, 0xff)
            if self.envelope_counter == 0xff then
                self.state = EnvelopeGenerator.State.DECAY_SUSTAIN
                self.rate_period = EnvelopeGenerator.rate_counter_period[self.decay]
            end
        elseif self.state == EnvelopeGenerator.State.DECAY_SUSTAIN then
            if self.envelope_counter ~= EnvelopeGenerator.sustain_level[self.sustain] then
                self.envelope_counter = self.envelope_counter - 1
            end
        elseif self.state == EnvelopeGenerator.State.RELEASE then
            self.envelope_counter = band(self.envelope_counter - 1, 0xff)
        end

        local e = self.envelope_counter
        if e == 0xff then
            self.exponential_counter_period = 1
        elseif e == 0x5d then
            self.exponential_counter_period = 2
        elseif e == 0x36 then
            self.exponential_counter_period = 4
        elseif e == 0x1a then
            self.exponential_counter_period = 8
        elseif e == 0x0e then
            self.exponential_counter_period = 16
        elseif e == 0x06 then
            self.exponential_counter_period = 30
        elseif e == 0x00 then
            self.exponential_counter_period = 1

            self.hold_zero = true
        end
    end
end

function EnvelopeGenerator:clock(delta_t)
    if not delta_t then return self:clock_0() end
    local rate_step = self.rate_period - self.rate_counter
    if rate_step <= 0 then
        rate_step = rate_step + 0x7fff
    end

    if delta_t < rate_step then
        self.rate_counter = self.rate_counter + delta_t
        if self.rate_counter >= 0x8000 then
            self.rate_counter = band(self.rate_counter + 1, 0x7fff)
        end
        return
    end

    local ATTACK, DECAY_SUSTAIN, RELEASE, decay, sustain = EnvelopeGenerator.State.ATTACK, EnvelopeGenerator.State.DECAY_SUSTAIN, EnvelopeGenerator.State.RELEASE, EnvelopeGenerator.rate_counter_period[self.decay], EnvelopeGenerator.sustain_level[self.sustain]
    local state, exponential_counter, exponential_counter_period, rate_period, envelope_counter, hold_zero = self.state, self.exponential_counter, self.exponential_counter_period, self.rate_period, self.envelope_counter, self.hold_zero

    while delta_t ~= 0 do
        if delta_t < rate_step then
            if delta_t >= 0x8000 then
                self.rate_counter = band(delta_t + 1, 0x7fff)
            else
                self.rate_counter = delta_t
            end
            self.state, self.exponential_counter, self.exponential_counter_period, self.rate_period, self.envelope_counter, self.hold_zero = state, exponential_counter, exponential_counter_period, rate_period, envelope_counter, hold_zero
            return
        end

        delta_t = delta_t - rate_step

        if state == ATTACK or exponential_counter + 1 == exponential_counter_period then
            exponential_counter = 0

            if hold_zero then
                rate_step = rate_period
            else

                if state == ATTACK then
                    envelope_counter = band(envelope_counter + 1, 0xff)
                    if envelope_counter == 0xff then
                        state = DECAY_SUSTAIN
                        rate_period = decay
                    end
                elseif state == DECAY_SUSTAIN then
                    if envelope_counter ~= sustain then
                        envelope_counter = envelope_counter - 1
                    end
                elseif state == RELEASE then
                    envelope_counter = band(envelope_counter - 1, 0xff)
                end

                if envelope_counter == 0xff then
                    exponential_counter_period = 1
                elseif envelope_counter == 0x5d then
                    exponential_counter_period = 2
                elseif envelope_counter == 0x36 then
                    exponential_counter_period = 4
                elseif envelope_counter == 0x1a then
                    exponential_counter_period = 8
                elseif envelope_counter == 0x0e then
                    exponential_counter_period = 16
                elseif envelope_counter == 0x06 then
                    exponential_counter_period = 30
                elseif envelope_counter == 0x00 then
                    exponential_counter_period = 1

                    hold_zero = true
                end
            end
        else exponential_counter = exponential_counter + 1 end

        rate_step = rate_period
    end

    self.rate_counter = 0
    self.state, self.exponential_counter, self.exponential_counter_period, self.rate_period, self.envelope_counter, self.hold_zero = state, exponential_counter, exponential_counter_period, rate_period, envelope_counter, hold_zero
end

function EnvelopeGenerator:output()
    return self.envelope_counter
end

-- * extfilt *

local ExternalFilter = {}
ExternalFilter.__index = ExternalFilter

function ExternalFilter:new()
    local obj = setmetatable({}, self)
    obj:reset()
    obj:enable_filter(true)
    obj:set_chip_model(chip_model.MOS6581)

    self.w0lp = 104858
    self.w0hp = 105
    return obj
end

function ExternalFilter:enable_filter(enable)
    self.enabled = enable
end

function ExternalFilter:set_chip_model(model)
    if model == chip_model.MOS6581 then
        --self.mixer_DC = rshift((((0x800 - 0x380) + 0x800)*0xff*3 - 0xfff*0xff/18), 7)*0x0f
        self.mixer_DC = 0x44601
    else
        self.mixer_DC = 0
    end
end

function ExternalFilter:clock_1(Vi)
    if not self.enabled then
        self.Vlp, self.Vhp = 0, 0
        self.Vo = Vi - self.mixer_DC
        return
    end

    local dVlp = arshift(arshift(self.w0lp, 8)*(Vi - self.Vlp), 12)
    local dVhp = arshift(self.w0hp*(self.Vlp - self.Vhp), 20)
    self.Vo = self.Vlp - self.Vhp
    self.Vlp = self.Vlp + dVlp
    self.Vhp = self.Vhp + dVhp
end

function ExternalFilter:clock(delta_t, Vi)
    if not Vi then return self:clock_1(delta_t) end
    if not self.enabled then
        self.Vlp, self.Vhp = 0, 0
        self.Vo = Vi - self.mixer_DC
        return
    end

    local Vo, Vlp, Vhp, w0hp, w0lp = self.Vo, self.Vlp, self.Vhp, self.w0hp / 131072, floor(self.w0lp / 32) / 4096
    for delta_t = delta_t, 0, -8 do
        if delta_t < 8 then
            local dVlp = arshift(arshift(w0lp*delta_t, 8)*(Vi - Vlp), 12)
            local dVhp = arshift(w0hp*delta_t*(Vlp - Vhp), 20)
            Vo = Vlp - Vhp
            Vlp = Vlp + dVlp
            Vhp = Vhp + dVhp
            break
        end

        local dVlp = floor(w0lp*(Vi - Vlp))
        local dVhp = floor(w0hp*(Vlp - Vhp))
        Vo = Vlp - Vhp
        Vlp = Vlp + dVlp
        Vhp = Vhp + dVhp
    end

    self.Vo, self.Vlp, self.Vhp = Vo, Vlp, Vhp
end

function ExternalFilter:reset()
    self.Vlp = 0
    self.Vhp = 0
    self.Vo = 0
end

function ExternalFilter:output()
    return self.Vo
end

-- * spline *

local function cubic_coefficients(x1, y1, x2, y2, k1, k2)
    local dx, dy = x2 - x1, y2 - y1

    local a = ((k1 + k2) - 2*dy/dx)/(dx*dx)
    local b = ((k2 - k1)/dx - 3*(x1 + x2)*a)/2
    local c = k1 - (3*x1*a + 2*b)*x1
    local d = y1 - ((x1*a + b)*x1 + c)*x1
    return a, b, c, d
end

local function interpolate_brute_force(x1, y1, x2, y2, k1, k2, plot, res)
    local a, b, c, d = cubic_coefficients(x1, y1, x2, y2, k1, k2)

    for x = x1, x2, res do
        local y = ((a*x + b)*x + c)*x + d
        plot(x, y)
    end
end

local function interpolate_forward_difference(x1, y1, x2, y2, k1, k2, plot, res)
    local a, b, c, d = cubic_coefficients(x1, y1, x2, y2, k1, k2)

    local y = ((a*x1 + b)*x1 + c)*x1 + d;
    local dy = (3*a*(x1 + res) + 2*b)*x1*res + ((a*res + b)*res + c)*res;
    local d2y = (6*a*(x1 + res) + 2*b)*res*res;
    local d3y = 6*a*res*res*res;

    for x = x1, x2, res do
        plot(x, y)
        y, dy, d2y = y + dy, dy + d2y, d2y + d3y
    end
end

local interpolate_segment
if SPLINE_BRUTE_FORCE then interpolate_segment = interpolate_brute_force
else interpolate_segment = interpolate_forward_difference end

local function interpolate(list, plot, res)
    local p0, p1, p2, p3 = list[1], list[2], list[3], list[4]
    for x = 5, #list + 1 do
        if p1[1] ~= p2[1] then
            local k1, k2
            if p0[1] == p1[1] and p2[1] == p3[1] then
                k1 = (p2[2] - p1[2])/(p2[1] - p1[1])
                k2 = k1
            elseif p0[1] == p1[1] then
                k2 = (p3[2] - p1[2])/(p3[1] - p1[1])
                k1 = (3*(p2[2] - p1[2])/(p2[1] - p1[1]) - k2)/2
            elseif p2[1] == p3[1] then
                k1 = (p2[2] - p0[2])/(p2[1] - p0[1])
                k2 = (3*(p2[2] - p1[2])/(p2[1] - p1[1]) - k1)/2
            else
                k1 = (p2[2] - p0[2])/(p2[1] - p0[1])
                k2 = (p3[2] - p1[2])/(p3[1] - p1[1])
            end

            interpolate_segment(p1[1], p1[2], p2[1], p2[2], k1, k2, plot, res)
        end
        p0, p1, p2, p3 = p1, p2, p3, list[x]
    end
end

local function PointPlotter(arr)
    return function(x, y)
        if y < 0 then y = 0 end
        arr[floor(x)] = floor(y)
    end
end

-- * filter *

local Filter = {}
Filter.__index = Filter

Filter.f0_points_6581 = {
    --  FC      f         FCHI FCLO
    -------------------------------
    {    0,   220 },   -- 0x00      - repeated end point
    {    0,   220 },   -- 0x00
    {  128,   230 },   -- 0x10
    {  256,   250 },   -- 0x20
    {  384,   300 },   -- 0x30
    {  512,   420 },   -- 0x40
    {  640,   780 },   -- 0x50
    {  768,  1600 },   -- 0x60
    {  832,  2300 },   -- 0x68
    {  896,  3200 },   -- 0x70
    {  960,  4300 },   -- 0x78
    {  992,  5000 },   -- 0x7c
    { 1008,  5400 },   -- 0x7e
    { 1016,  5700 },   -- 0x7f
    { 1023,  6000 },   -- 0x7f 0x07
    { 1023,  6000 },   -- 0x7f 0x07 - discontinuity
    { 1024,  4600 },   -- 0x80      -
    { 1024,  4600 },   -- 0x80
    { 1032,  4800 },   -- 0x81
    { 1056,  5300 },   -- 0x84
    { 1088,  6000 },   -- 0x88
    { 1120,  6600 },   -- 0x8c
    { 1152,  7200 },   -- 0x90
    { 1280,  9500 },   -- 0xa0
    { 1408, 12000 },   -- 0xb0
    { 1536, 14500 },   -- 0xc0
    { 1664, 16000 },   -- 0xd0
    { 1792, 17100 },   -- 0xe0
    { 1920, 17700 },   -- 0xf0
    { 2047, 18000 },   -- 0xff 0x07
    { 2047, 18000 }    -- 0xff 0x07 - repeated end point
}

Filter.f0_points_8580 = {
    --  FC      f         FCHI FCLO
    -------------------------------
    {    0,     0 },   -- 0x00      - repeated end point
    {    0,     0 },   -- 0x00
    {  128,   800 },   -- 0x10
    {  256,  1600 },   -- 0x20
    {  384,  2500 },   -- 0x30
    {  512,  3300 },   -- 0x40
    {  640,  4100 },   -- 0x50
    {  768,  4800 },   -- 0x60
    {  896,  5600 },   -- 0x70
    { 1024,  6500 },   -- 0x80
    { 1152,  7500 },   -- 0x90
    { 1280,  8400 },   -- 0xa0
    { 1408,  9200 },   -- 0xb0
    { 1536,  9800 },   -- 0xc0
    { 1664, 10500 },   -- 0xd0
    { 1792, 11000 },   -- 0xe0
    { 1920, 11700 },   -- 0xf0
    { 2047, 12500 },   -- 0xff 0x07
    { 2047, 12500 }    -- 0xff 0x07 - repeated end point
}

function Filter:new()
    local obj = setmetatable({f0_6581 = {}, f0_8580 = {}}, self)
    obj.fc = 0

    obj.res = 0

    obj.filt = 0

    obj.voice3off = false

    obj.hp_bp_lp = 0

    obj.vol = 0

    obj.Vhp = 0
    obj.Vbp = 0
    obj.Vlp = 0
    obj.Vnf = 0

    obj:enable_filter(true)

    interpolate(self.f0_points_6581, PointPlotter(obj.f0_6581), 1.0)
    interpolate(self.f0_points_8580, PointPlotter(obj.f0_8580), 1.0)

    obj:set_chip_model(chip_model.MOS6581)
    return obj
end

function Filter:enable_filter(enable)
    self.enabled = enable
end

function Filter:set_chip_model(model)
    if model == chip_model.MOS6581 then
        self.mixer_DC = -0x1C5

        self.f0 = self.f0_6581
        self.f0_points = Filter.f0_points_6581
        self.f0_count = #self.f0_points
    else
        self.mixer_DC = 0

        self.f0 = self.f0_8580
        self.f0_points = Filter.f0_points_8580
        self.f0_count = #self.f0_points
    end

    self:set_w0()
    self:set_Q()
end

function Filter:clock_4(voice1, voice2, voice3, ext_in)
    voice1 = arshift(voice1, 7)
    voice2 = arshift(voice2, 7)

    if self.voice3off and not btest(self.filt, 0x04) then
        voice3 = 0
    else
        voice3 = arshift(voice3, 7)
    end

    --ext_in = arshift(ext_in, 7)

    if not self.enabled then
        self.Vnf = voice1 + voice2 + voice3 --+ ext_in
        self.Vhp, self.Vbp, self.Vlp = 0, 0, 0
        return
    end

    local Vi =  (btest(self.filt, 1) and voice1 or 0) +
                (btest(self.filt, 2) and voice2 or 0) +
                (btest(self.filt, 4) and voice3 or 0)
                --(btest(self.filt, 8) and ext_in or 0)
    self.Vnf =  (btest(self.filt, 1) and 0 or voice1) +
                (btest(self.filt, 2) and 0 or voice2) +
                (btest(self.filt, 4) and 0 or voice3)
                --(btest(self.filt, 8) and 0 or ext_in)

    local dVbp = arshift(self.w0_ceil_1*self.Vhp, 20)
    local dVlp = arshift(self.w0_ceil_1*self.Vbp, 20)
    self.Vbp = self.Vbp - dVbp
    self.Vlp = self.Vlp - dVlp
    self.Vhp = arshift(self.Vbp*self._1024_div_Q, 10) - self.Vlp - Vi
end

function Filter:clock(delta_t, voice1, voice2, voice3, ext_in)
    if not ext_in then return self:clock_4(delta_t, voice1, voice2, voice3) end
    voice1 = arshift(voice1, 7)
    voice2 = arshift(voice2, 7)

    if self.voice3off and not btest(self.filt, 0x04) then
        voice3 = 0
    else
        voice3 = arshift(voice3, 7)
    end

    --ext_in = arshift(ext_in, 7)

    if not self.enabled then
        self.Vnf = voice1 + voice2 + voice3 --+ ext_in
        self.Vhp, self.Vbp, self.Vlp = 0, 0, 0
        return
    end

    local Vi =  (btest(self.filt, 1) and voice1 or 0) +
                (btest(self.filt, 2) and voice2 or 0) +
                (btest(self.filt, 4) and voice3 or 0)
                --(btest(self.filt, 8) and ext_in or 0)
    self.Vnf =  (btest(self.filt, 1) and 0 or voice1) +
                (btest(self.filt, 2) and 0 or voice2) +
                (btest(self.filt, 4) and 0 or voice3)
                --(btest(self.filt, 8) and 0 or ext_in)

    local Vbp, Vlp, Vhp, w0_ceil_dt, Q = self.Vbp, self.Vlp, self.Vhp, self.w0_ceil_dt, self._1024_div_Q / 1024
    local w0_delta_t = floor(w0_ceil_dt / 8) / 0x4000
    for delta_t = delta_t, 0, -8 do
        if delta_t < 8 then
            w0_delta_t = floor(w0_ceil_dt*delta_t / 64) / 0x4000

            local dVbp = floor(w0_delta_t*Vhp)
            local dVlp = floor(w0_delta_t*Vbp)
            Vbp = Vbp - dVbp
            Vlp = Vlp - dVlp
            Vhp = floor(Vbp*Q) - Vlp - Vi
            break
        end

        local dVbp = floor(w0_delta_t*Vhp)
        local dVlp = floor(w0_delta_t*Vbp)
        Vbp = Vbp - dVbp
        Vlp = Vlp - dVlp
        Vhp = floor(Vbp*Q) - Vlp - Vi
    end
    self.Vbp, self.Vlp, self.Vhp = Vbp, Vlp, Vhp
end

function Filter:reset()
    self.fc = 0

    self.res = 0

    self.filt = 0

    self.voice3off = false

    self.hp_bp_lp = 0

    self.vol = 0

    self.Vhp = 0
    self.Vbp = 0
    self.Vlp = 0
    self.Vnf = 0

    self:set_w0()
    self:set_Q()
end

function Filter:writeFC_LO(fc_lo)
    self.fc = bor(band(self.fc, 0x7f8), band(fc_lo, 0x007))
    self:set_w0()
end

function Filter:writeFC_HI(fc_hi)
    self.fc = bor(band(lshift(fc_hi, 3), 0x7f8), band(self.fc, 0x007))
    self:set_w0()
end

function Filter:writeRES_FILT(res_filt)
    self.res = band(rshift(res_filt, 4), 0x0f)
    self:set_Q()

    self.filt = band(res_filt, 0x0f)
end

function Filter:writeMODE_VOL(mode_vol)
    self.voice3off = btest(mode_vol, 0x80)

    self.hp_bp_lp = band(rshift(mode_vol, 4), 0x07)

    self.vol = band(mode_vol, 0x0f)
end

function Filter:output()
    if not self.enabled then
        return (self.Vnf + self.mixer_DC)*self.vol
    end

    local Vf =  (btest(self.hp_bp_lp, 1) and self.Vlp or 0) +
                (btest(self.hp_bp_lp, 2) and self.Vbp or 0) +
                (btest(self.hp_bp_lp, 4) and self.Vhp or 0)

    return (self.Vnf + Vf + self.mixer_DC)*self.vol
end

function Filter:fc_default()
    return self.f0_points, self.f0_count
end

function Filter:fc_plotter()
    return PointPlotter(self.f0)
end

function Filter:set_w0()
    self.w0 = floor(2*pi*self.f0[self.fc]*1.048576)

    local w0_max_1 = floor(2*pi*16000*1.048576)
    self.w0_ceil_1 = min(self.w0, w0_max_1)

    local w0_max_dt = floor(2*pi*4000*1.048576)
    self.w0_ceil_dt = min(self.w0, w0_max_dt)
end

function Filter:set_Q()
    self._1024_div_Q = floor(1024.0/(0.707 + 1.0*self.res/0x0f))
end

-- * wave *

local WaveformGenerator = {}
WaveformGenerator.__index = WaveformGenerator

function WaveformGenerator:new()
    local obj = setmetatable({}, self)
    obj.sync_source = obj

    obj:set_chip_model(chip_model.MOS6581)

    obj:reset()
    return obj
end

function WaveformGenerator:set_sync_source(source)
    self.sync_source = source
    source.sync_dest = self
end

function WaveformGenerator:set_chip_model(model)
    if model == chip_model.MOS6581 then
        self.wave__ST = WaveformGenerator.wave6581__ST
        self.wave_P_T = WaveformGenerator.wave6581_P_T
        self.wave_PS_ = WaveformGenerator.wave6581_PS_
        self.wave_PST = WaveformGenerator.wave6581_PST
    else
        self.wave__ST = WaveformGenerator.wave8580__ST
        self.wave_P_T = WaveformGenerator.wave8580_P_T
        self.wave_PS_ = WaveformGenerator.wave8580_PS_
        self.wave_PST = WaveformGenerator.wave8580_PST
    end
end

function WaveformGenerator:clock_0()
    if self.test then
        return
    end

    local accumulator_prev = self.accumulator

    self.accumulator = band(self.accumulator + self.freq, 0xffffff)

    self.msb_rising = accumulator_prev < 0x800000 and self.accumulator >= 0x800000

    if not btest(accumulator_prev, 0x080000) and btest(self.accumulator, 0x080000) then
        local bit0 = band(bxor(rshift(self.shift_register, 22), rshift(self.shift_register, 17)), 0x1)
        self.shift_register = bor(band(lshift(self.shift_register, 1), 0x7fffff), bit0)
    end
end

function WaveformGenerator:clock(delta_t)
    if not delta_t then return self:clock_0() end
    if self.test then
        return
    end

    local accumulator_prev = self.accumulator

    local delta_accumulator = delta_t*self.freq
    self.accumulator = band(self.accumulator + delta_accumulator, 0xffffff)

    self.msb_rising = accumulator_prev < 0x800000 and self.accumulator >= 0x800000

    local shift_period = 0x100000

    local shift_register = self.shift_register
    while delta_accumulator ~= 0 do
        if delta_accumulator < shift_period then
            shift_period = delta_accumulator
            if shift_period <= 0x080000 then
                if btest(self.accumulator - shift_period, 0x080000) or not btest(self.accumulator, 0x080000) then
                    break
                end
            else
                if btest(self.accumulator - shift_period, 0x080000) and not btest(self.accumulator, 0x080000) then
                    break
                end
            end
        end

        local bit0 = bxor(rshift(shift_register, 22), rshift(shift_register, 17)) % 2
        shift_register = band(lshift(shift_register, 1), 0x7fffff) + bit0

        delta_accumulator = delta_accumulator - shift_period
    end
    self.shift_register = shift_register
end

function WaveformGenerator:synchronize()
    if self.msb_rising and self.sync_dest.sync and not (self.sync and self.sync_source.msb_rising) then
        self.sync_dest.accumulator = 0
    end
end

function WaveformGenerator:reset()
    self.accumulator = 0
    self.shift_register = 0x7ffff8
    self.freq = 0
    self.pw = 0
    self.waveform = 0
    self.output = WaveformGenerator.outputs[0]

    self.test = 0
    self.ring_mod = 0
    self.sync = false

    self.msb_rising = false
end

function WaveformGenerator:writeFREQ_LO(freq_lo)
    self.freq = bor(band(self.freq, 0xff00), band(freq_lo, 0x00ff))
end

function WaveformGenerator:writeFREQ_HI(freq_hi)
    self.freq = bor(band(lshift(freq_hi, 8), 0xff00), band(self.freq, 0x00ff))
end

function WaveformGenerator:writePW_LO(pw_lo)
    self.pw = bor(band(self.pw, 0xf00), band(pw_lo, 0x0ff))
end

function WaveformGenerator:writePW_HI(pw_hi)
    self.pw = bor(band(lshift(pw_hi, 8), 0xf00), band(self.pw, 0x0ff))
end

function WaveformGenerator:writeCONTROL_REG(control)
    self.waveform = band(rshift(control, 4), 0x0f)
    self.output = WaveformGenerator.outputs[self.waveform]
    self.ring_mod = btest(control, 0x04)
    self.sync = btest(control, 0x02)

    local test_next = btest(control, 0x08)

    if test_next then
        self.accumulator = 0
        self.shift_register = 0
    elseif self.test then
        self.shift_register = 0x7ffff8
    end

    self.test = test_next
end

function WaveformGenerator:readOSC()
    return rshift(self:output(), 4)
end

function WaveformGenerator:output()
    --return WaveformGenerator.outputs[self.waveform](self)
    -- O(log n) search for the correct output type
    if self.waveform < 8 then
        if self.waveform % 8 < 4 then
            if self.waveform % 4 < 2 then
                if self.waveform % 2 == 0 then
                    return 0x000
                else
                    local msb = (self.ring_mod and bxor(self.accumulator, self.sync_source.accumulator) or self.accumulator) >= 0x800000
                    return band(rshift(msb and bnot(self.accumulator) or self.accumulator, 11), 0xfff)
                end
            else
                if self.waveform % 2 == 0 then
                    return rshift(self.accumulator, 12)
                else
                    local s = rshift(self.accumulator, 12)
                    return lshift(self.wave__ST[s], 4)
                end
            end
        else
            local p = (self.test or rshift(self.accumulator, 12) >= self.pw) and 0xfff or 0x000
            if self.waveform % 4 < 2 then
                if self.waveform % 2 == 0 then
                    return p
                else
                    local msb = (self.ring_mod and bxor(self.accumulator, self.sync_source.accumulator) or self.accumulator) >= 0x800000
                    local t = band(rshift(msb and bnot(self.accumulator) or self.accumulator, 11), 0xfff)
                    return band(lshift(self.wave_P_T[rshift(t, 1)], 4), p)
                end
            else
                local s = rshift(self.accumulator, 12)
                local t = self.waveform % 2 == 0 and self.wave_PS_ or self.wave_PST
                return band(lshift(t[s], 4), p)
            end
        end
    elseif self.waveform == 8 then
        return bor(
            rshift(band(self.shift_register, 0x400000), 11),
            rshift(band(self.shift_register, 0x100000), 10),
            rshift(band(self.shift_register, 0x010000), 7),
            rshift(band(self.shift_register, 0x002000), 5),
            rshift(band(self.shift_register, 0x000800), 4),
            rshift(band(self.shift_register, 0x000080), 1),
            lshift(band(self.shift_register, 0x000010), 1),
            lshift(band(self.shift_register, 0x000004), 2)
        )
    else return 0 end
end

WaveformGenerator.outputs = {
    [0] = function(self) -- ____
        return 0x000
    end,
    function(self) -- ___T
        local msb = (self.ring_mod and bxor(self.accumulator, self.sync_source.accumulator) or self.accumulator) >= 0x800000
        return band(rshift(msb and bnot(self.accumulator) or self.accumulator, 11), 0xfff)
    end,
    function(self) -- __S_
        return rshift(self.accumulator, 12)
    end,
    function(self) -- __ST
        return lshift(self.wave__ST[rshift(self.accumulator, 12)], 4)
    end,
    function(self) -- _P__
        return (self.test or rshift(self.accumulator, 12) >= self.pw) and 0xfff or 0x000
    end,
    function(self) -- _P_T
        local p = (self.test or rshift(self.accumulator, 12) >= self.pw) and 0xfff or 0x000
        local msb = (self.ring_mod and bxor(self.accumulator, self.sync_source.accumulator) or self.accumulator) >= 0x800000
        local t = band(rshift(msb and bnot(self.accumulator) or self.accumulator, 11), 0xfff)
        return band(lshift(self.wave_P_T[rshift(t, 1)], 4), p)
    end,
    function(self) -- _PS_
        local p = (self.test or rshift(self.accumulator, 12) >= self.pw) and 0xfff or 0x000
        local s = rshift(self.accumulator, 12)
        return band(lshift(self.wave_PS_[s], 4), p)
    end,
    function(self) -- _PST
        local p = (self.test or rshift(self.accumulator, 12) >= self.pw) and 0xfff or 0x000
        local s = rshift(self.accumulator, 12)
        return band(lshift(self.wave_PST[s], 4), p)
    end,
    function(self) -- N___
        return bor(
            rshift(band(self.shift_register, 0x400000), 11),
            rshift(band(self.shift_register, 0x100000), 10),
            rshift(band(self.shift_register, 0x010000), 7),
            rshift(band(self.shift_register, 0x002000), 5),
            rshift(band(self.shift_register, 0x000800), 4),
            rshift(band(self.shift_register, 0x000080), 1),
            lshift(band(self.shift_register, 0x000010), 1),
            lshift(band(self.shift_register, 0x000004), 2)
        )
    end,
    function(self) -- N__T
        return 0
    end,
    function(self) -- N_S_
        return 0
    end,
    function(self) -- N_ST
        return 0
    end,
    function(self) -- NP__
        return 0
    end,
    function(self) -- NP_T
        return 0
    end,
    function(self) -- NPS_
        return 0
    end,
    function(self) -- NPST
        return 0
    end
}

-- * wavetables *

local function unrle(s)
    local r = ""
    for c, n in s:gmatch "(.)(.)" do r = r .. c:rep(n:byte()) end
    local t = {r:byte(2, -1)}
    t[0] = r:byte()
    return t
end

WaveformGenerator.wave6581__ST = unrle "\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0008\x0E\x04\x0F\x04\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0\x30\x1C\x08\x1E\x04\x1F\x02?\x02\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0008\x0E\x04\x0F\x03\x1F\x01\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0\x208\x10<\x08>\x02?\x02\x7F\x04\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0008\x0E\x04\x0F\x04\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0\x30\x1C\x08\x1E\x04\x1F\x02?\x02\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0008\x0E\x04\x0F\x03\x1F\x01\0~\x03\x02\0?\x01\x01\0<\x07\x04\0?\x01\x01\0>\x03\x02\0?\x01\x01\0\x208\x10<\x08>\x02?\x02\x7F\x04"
WaveformGenerator.wave6581_P_T = unrle "\0\xFF\0\xFE \x018\x01?\x01\0\xFB@\x01\0\x01@\x02_\x01\0o@\x01\0\x07@\x01\0\x03`\x01\0\x01`\x02o\x01\0\x1F@\x01\0\x0F`\x01\0\x07`\x01\0\x03`\x01\0\x01`\x01p\x01w\x01\0\x0F`\x01\0\x07`\x01\0\x03p\x01@\x01p\x02{\x01\0\x06@\x01p\x01\0\x01@\x02p\x01`\x01p\x01x\x01}\x01\0\x01@\x01`\x01x\x01`\x01x\x02~\x01p\x01|\x02\x7F\x01~\x01\x7F\x03\0\x7F\x80\x01\0?\x80\x01\0\x1F\x80\x01\0\x0F\x80\x01\0\x07\x80\x01\0\x03\x80\x04\x9F\x01\0?\x80\x01\0\x1F\x80\x01\0\x0F\x80\x01\0\x07\x80\x01\0\x01\x80\x04\xA0\x02\xAF\x01\0\x1F\x80\x01\0\x0D\x80\x03\0\x03\x80\x01\0\x01\x80\x02\xA0\x01\0\x01\x80\x02\xA0\x01\x80\x01\xA0\x01\xB0\x01\xB7\x01\0\x07\x80\x01\0\x03\x80\x01\0\x01\x80\x02\xA0\x01\0\x03\x80\x01\0\x01\x80\x02\xA0\x01\0\x01\x80\x02\xA0\x01\x80\x01\xB0\x02\xBB\x01\0\x03\x80\x04\xB0\x01\x80\x03\xB0\x01\x80\x01\xB0\x01\xB8\x01\xBD\x01\x80\x03\xB8\x01\xA0\x01\xB8\x02\xBE\x01\xA0\x01\xB8\x01\xBC\x01\xBF\x01\xBE\x01\xBF\x03\0?\xC0\x01\0\x1D\x80\x02\xC0\x01\0\x0B\x80\x01\0\x01\x80\x02\xC0\x01\0\x03\x80\x01\0\x01\x80\x02\xC0\x01\0\x01\x80\x02\xC0\x04\xCF\x01\0\x0F\x80\x01\0\x07\x80\x01\0\x03\x80\x01\0\x01\x80\x02\xC0\x01\0\x07\x80\x01\0\x03\x80\x01\0\x01\x80\x02\xC0\x01\0\x03\x80\x01\0\x01\x80\x01\xC0\x02\x80\x01\xC0\x05\xD0\x01\xD7\x01\0\x07\x80\x01\0\x03\x80\x03\xC0\x02\0\x01\x80\x02\xC0\x01\x80\x01\xC0\x03\x80\x01\xC0\x04\xD0\x02\xDB\x01\0\x01\x80\x02\xC0\x01\x80\x01\xC0\x02\xD0\x01\x80\x01\xC0\x02\xD0\x01\xC0\x01\xD0\x01\xD8\x01\xDD\x01\xC0\x03\xD0\x01\xC0\x01\xD8\x02\xDE\x01\xC0\x01\xD8\x01\xDC\x01\xDF\x01\xDC\x01\xDF\x03\0\x0F\x80\x01\0\x07\x80\x01\0\x03\x80\x02\xC0\x02\xE0\x01\0\x07\x80\x01\0\x01\x80\x02\xC0\x01\x80\x01\xC0\x02\xE0\x01\0\x01\x80\x02\xC0\x01\x80\x01\xC0\x02\xE0\x01\x80\x01\xC0\x02\xE0\x01\xC0\x01\xE0\x02\xE7\x01\0\x03\x80\x01\0\x01\x80\x02\xC0\x01\0\x01\x80\x02\xC0\x01\x80\x01\xC0\x02\xE0\x01\0\x01\x80\x02\xC0\x01\x80\x01\xC0\x02\xE0\x01\xC0\x03\xE0\x04\xEB\x01\x80\x02\xC0\x05\xE0\x01\xC0\x01\xE0\x06\xED\x01\xC0\x01\xE0\x04\xE8\x02\xEE\x01\xE0\x01\xE8\x01\xEC\x01\xEF\x01\xEC\x01\xEF\x03\0\x03\x80\x04\xC0\x01\x80\x02\xC0\x05\xF0\x01\x80\x01\xC0\x04\xE0\x02\xF0\x01\xC0\x01\xE0\x02\xF0\x01\xE0\x01\xF0\x02\xF3\x01\x80\x01\xC0\x02\xE0\x01\xC0\x01\xE0\x02\xF0\x01\xC0\x01\xE0\x02\xF0\x01\xE0\x01\xF0\x02\xF5\x01\xE0\x03\xF0\x04\xF6\x01\xF0\x02\xF4\x01\xF7\x01\xF4\x01\xF7\x03\xC0\x03\xE0\x04\xF0\x01\xE0\x03\xF8\x01\xF0\x01\xF8\x02\xF9\x01\xE0\x01\xF0\x02\xF8\x01\xF0\x01\xF8\x02\xFA\x01\xF0\x01\xF8\x02\xFB\x01\xF8\x01\xFB\x03\xE0\x01\xF0\x02\xF8\x01\xF0\x01\xF8\x01\xFC\x02\xF8\x01\xFC\x02\xFD\x01\xFC\x01\xFD\x03\xF8\x01\xFC\x01\xFE\x07\xFF\x0E\xFE\x07\xFC\x01\xF8\x01\xFD\x03\xFC\x01\xFD\x01\xFC\x02\xF8\x01\xFC\x03\xF0\x01\xF8\x01\xF0\x02\xE0\x01\xFB\x03\xF8\x01\xFB\x01\xF8\x02\xF0\x01\xFA\x01\xF8\x02\xF0\x01\xF8\x01\xF0\x02\xE0\x01\xF9\x01\xF8\x02\xF0\x01\xF8\x01\xF0\x01\xE0\x02\xF0\x01\xE0\x04\xC0\x03\xF7\x03\xF4\x01\xF7\x01\xF4\x01\xF0\x02\xF6\x01\xF0\x04\xE0\x03\xF5\x01\xF0\x02\xE0\x01\xF0\x01\xE0\x02\xC0\x01\xF0\x01\xE0\x02\xC0\x01\xE0\x01\xC0\x02\x80\x01\xF3\x01\xF0\x02\xE0\x01\xF0\x01\xE0\x02\xC0\x01\xF0\x01\xE0\x02\xC0\x04\x80\x01\xF0\x01\xE0\x01\xC0\x04\x80\x02\xC0\x01\x80\x04\0\x03\xEF\x03\xEC\x01\xEF\x01\xEC\x01\xE8\x01\xE0\x01\xEE\x01\xE8\x02\xE0\x04\xC0\x01\xED\x01\xE8\x01\xE0\x05\xC0\x01\xE0\x02\xC0\x04\x80\x02\xEB\x01\xE0\x04\xC0\x03\xE0\x01\xC0\x02\x80\x01\xC0\x01\x80\x02\0\x01\xE0\x01\xC0\x02\x80\x01\xC0\x01\x80\x02\0\x01\xC0\x01\x80\x02\0\x01\x80\x01\0\x03\xE7\x01\xE0\x02\xC0\x01\xE0\x01\xC0\x02\x80\x01\xE0\x01\xC0\x02\x80\x01\xC0\x01\x80\x02\0\x01\xE0\x01\xC0\x02\x80\x01\xC0\x01\x80\x02\0\x01\x80\x02\0\x06\xE0\x01\xC0\x02\x80\x02\0\x03\x80\x01\0\x07\x80\x01\0\x0F\xDF\x03\xDC\x01\xDF\x01\xDC\x01\xD8\x01\xC0\x01\xDE\x01\xD8\x02\xC0\x01\xD8\x01\xC0\x03\xDD\x01\xD8\x01\xD0\x01\xC0\x01\xD0\x01\xC0\x02\x80\x01\xD0\x01\xC0\x02\x80\x01\xC0\x01\x80\x02\0\x01\xDB\x01\xD0\x02\xC0\x04\x80\x01\xC0\x03\x80\x01\xC0\x01\x80\x02\0\x01\xC0\x02\x80\x03\0\x03\x80\x01\0\x07\xD7\x01\xD0\x01\xC0\x05\x80\x01\xC0\x02\x80\x01\0\x01\x80\x01\0\x03\xC0\x01\x80\x02\0\x01\x80\x01\0\x03\x80\x01\0\x07\xC0\x01\x80\x02\0\x01\x80\x01\0\x03\x80\x01\0\x07\x80\x01\0\x0F\xCF\x01\xC0\x04\x80\x02\0\x01\xC0\x01\x80\x02\0\x01\x80\x01\0\x03\xC0\x01\x80\x02\0\x01\x80\x01\0\x0B\xC0\x01\x80\x02\0\x1D\xC0\x01\x80\x01\0>\xBF\x03\xBE\x01\xBF\x01\xBC\x02\xA0\x01\xBE\x01\xBC\x01\xB8\x01\xA0\x01\xB8\x01\xA0\x01\x80\x02\xBD\x01\xB8\x01\xB0\x01\x80\x01\xB0\x01\x80\x03\xB0\x01\x80\x04\0\x03\xBB\x01\xB0\x02\x80\x01\xA0\x01\x80\x02\0\x01\xA0\x01\x80\x02\0\x01\x80\x01\0\x03\xA0\x01\x80\x02\0\x01\x80\x01\0\x03\x80\x01\0\x07\xB7\x01\xB0\x01\xA0\x01\x80\x01\xA0\x01\x80\x02\0\x01\xA0\x01\x80\x02\0\x01\x80\x01\0\x03\x80\x03\0\x0D\x80\x02\0\x1E\xAF\x01\xA0\x02\x80\x04\0\x01\x80\x02\0\x06\x80\x01\0\x0F\x80\x01\0\x1F\x80\x01\0?\x9F\x01\x90\x01\x80\x03\0\x03\x80\x01\0\x07\x80\x01\0\x0F\x80\x01\0\x1F\x80\x01\0?\x80\x01\0\x7F\x7F\x03~\x01\x7F\x01|\x02p\x01~\x01|\x01x\x01`\x01x\x01`\x02\0\x01}\x01x\x02`\x01p\x01@\x02\0\x01p\x01@\x01\0\x06{\x01x\x01p\x01@\x01p\x01@\x01\0\x02`\x01\0\x07`\x01\0\x0Fw\x01p\x02\0\x01`\x01\0\x03`\x01\0\x07`\x01\0\x0F@\x01\0\x1Fo\x01`\x02\0\x01`\x01\0\x03@\x01\0\x07@\x01\0o_\x01X\x01@\x01\0\x01@\x01\0\x03@\x01\0\xF7?\x01<\x010\x01\0\xFF\0\xFE"
WaveformGenerator.wave6581_PS_ = unrle "\0\xFF\x07\x01\0\x7F\x03\x01\0?\x03\x01\0>\x02\x01\x1F\x01\0\x7F\x03\x01\0?\x01\x01\0?\x2F\x01\0\x7F7\x01\0?;\x01\0\x1F=\x01\0\x0F>\x01\0\x06\x30\x01?\x01\0\x01\x30\x018\x01?\x01>\x01?\x03\0\x7F\x03\x01\0\x7FO\x01\0\x7FW\x01\0?[\x01\0\x1F]\x01\0\x0F^\x01\0\x06@\x01_\x01\0\x01@\x02_\x01\x5C\x01_\x03\0\x7Fg\x01\0>@\x01k\x01\0\x1D@\x02m\x01\0\x07@\x01\0\x03@\x01\0\x01@\x02n\x01\0\x03@\x01\0\x01`\x02o\x01\0\x01`\x02o\x01`\x01o\x03\0\x1F@\x01\0\x0F@\x01\0\x07@\x01\0\x03@\x01\0\x01@\x01`\x01s\x01\0\x0F@\x01\0\x07@\x01\0\x03@\x01\0\x01`\x02u\x01\0\x07`\x01\0\x03`\x01\0\x01`\x02v\x01\0\x03`\x01\0\x01`\x02w\x01\0\x01p\x02w\x01p\x01w\x03\0\x0F`\x01\0\x07`\x01\0\x03`\x01\0\x01`\x02y\x01\0\x07`\x01\0\x03`\x01\0\x01p\x02z\x01\0\x03p\x01\0\x01p\x02{\x01@\x01p\x02{\x01x\x01{\x03\0\x07p\x01\0\x03p\x01\0\x01p\x02|\x01\0\x03p\x01@\x01p\x02}\x01@\x01p\x01x\x01}\x01x\x01}\x03\0\x01@\x02x\x01`\x01x\x02~\x01`\x01x\x02~\x01|\x01~\x03p\x01|\x02\x7F\x01~\x01\x7F\x03~\x01\x7F\x07\0\xFF\x07\x01\0\x7F\x03\x01\0?\x03\x01\0>\x02\x01\x1F\x01\0\x7F\x03\x01\0?\x01\x01\0?\x2F\x01\0\x7F7\x01\0?;\x01\0\x1F=\x01\0\x0F>\x01\0\x06\x30\x01?\x01\0\x01\x30\x018\x01?\x01>\x01?\x03\0\x7F\x03\x01\0\x7FO\x01\0\x7FW\x01\0?[\x01\0\x1F]\x01\0\x0F^\x01\0\x06@\x01_\x01\0\x01@\x02_\x01\x5C\x01_\x03\0\x7Fg\x01\0>@\x01k\x01\0\x1E@\x01m\x01\0\x07@\x01\0\x03@\x01\0\x01@\x02n\x01\0\x03@\x01\0\x01`\x02o\x01\0\x01`\x02o\x01`\x01o\x03\0\x1F@\x01\0\x0F@\x01\0\x07@\x01\0\x03@\x01\0\x01@\x01`\x01s\x01\0\x0F@\x01\0\x07@\x01\0\x03@\x01\0\x01`\x02u\x01\0\x07`\x01\0\x03`\x01\0\x01`\x02v\x01\0\x03`\x01\0\x01`\x02w\x01\0\x01p\x02w\x01p\x01w\x03\0\x0F`\x01\0\x07`\x01\0\x03`\x01\0\x01`\x02y\x01\0\x07`\x01\0\x03`\x01\0\x01p\x02z\x01\0\x03p\x01\0\x01p\x02{\x01@\x01p\x02{\x01x\x01{\x03\0\x07p\x01\0\x03p\x01\0\x01p\x02|\x01\0\x03p\x01@\x01p\x02}\x01@\x01p\x01x\x01}\x01x\x01}\x03\0\x01@\x02x\x01`\x01x\x02~\x01`\x01x\x02~\x01|\x01~\x03p\x01|\x02\x7F\x01|\x01\x7F\x03~\x01\x7F\x07"
WaveformGenerator.wave6581_PST = unrle "\0\xFF\0\xFF\0\xFF\0\xFF\0\x03?\x01\0\xFF\0\xFF\0\xFF\0\xF2 \x01\0\x070\x01\0\x03x\x02~\x01\x7F\x02\0\xFF\0\xFF\0\xFF\0\xFF\0\x03?\x01\0\xFF\0\xFF\0\xFF\0\xF2 \x01\0\x070\x01\0\x03x\x02~\x01\x7F\x02"

WaveformGenerator.wave8580__ST = unrle "\0~\x03\x02\0|\x07\x04\0~\x03\x02\0x\x0E\x04\x0F\x04\0~\x03\x02\0|\x07\x04\0~\x03\x02\0?\x01\x01\0000\x1C\x08\x1E\x02\x1F\x06\0~\x03\x02\0|\x07\x04\0~\x03\x02\0x\x0E\x04\x0F\x03\x1F\x01\0~\x03\x02\0|\x07\x04\0~\x03\x02\0?\x01\x01\0 8\x10<\x07>\x01\x7F\x08\0~\x03\x02\0|\x07\x04\0~\x03\x02\0x\x0E\x04\x0F\x04\0~\x03\x02\0|\x07\x04\0~\x03\x02\0?\x01\x01\0000\x1C\x08\x1E\x02\x1F\x04?\x02\0~\x03\x02\0|\x07\x04\0~\x03\x02\0?\x01\x01\0008\x0E\x04\x0F\x02\x1F\x02\0|\x80\x01\0\x01\x83\x02\x80|\x87\x03\x8F\x01\xC0\x01\xE0\x02\xC0\x02\xE0\x04\xC0\x08\xE0\x02\xC0\x05\xE0\x01\xC0\x08\xE0\x02\xC0\x02\xE0\x06\xC0\x01\xE0\x01\xC0\x01\xE0P\xE3\x02\xF0?\xF1\x01\xF8 \xFC\x10\xFE\x08\xFF\x08"
WaveformGenerator.wave8580_P_T = unrle "\0\xFF\x07\x01\0\xFB\x1C\x01\0\x01<\x01?\x02\0\xFD\x0C\x01^\x01_\x01\0w@\x01\0\x03@\x02`\x02o\x01\0\x1F@\x01\0\x0E@\x02\0\x03@\x04`\x01@\x02`\x04p\x01w\x01\0\x05@\x08`\x03@\x03`\x04p\x01`\x03p\x03x\x01{\x01`\x03p\x01`\x01p\x06x\x04|\x01x\x03|\x01x\x01|\x02~\x01|\x01~\x02\x7F\x05\0\x7F\x80\x01\0=\x80\x03\0\x0F\x80\x01\0\x07\x80\x01\0\x02\x80\x06\0\x03\x80\x1B\x8E\x01\x9F\x01\0\x1F\x80\x01\0\x0B\x80\x01\0\x01\x80\x03\0\x02\x80\x0E\0\x03\x80\x01\0\x01\x80:\xAF\x01\x80;\xA0\x04\xB7\x01\x80\x0F\xA0\x01\x80\x06\xA0\x05\xB0\x01\xA0\x01\xB0\x02\xBB\x01\xA0\x06\xB0\x02\xA0\x01\xB0\x02\xB8\x01\xB0\x01\xB8\x02\xBC\x01\xB0\x01\xB8\x04\xBC\x02\xBE\x01\xBC\x02\xBE\x01\xBF\x01\xBE\x01\xBF\x03\x80>\xC0\x02\x80\x17\xC0\x01\x80\x02\xC0\x06\x80\x03\xC0\x01\x80\x01\xC0\x1A\xCF\x01\x80\x06\xC0\x03\x80\x01\xC05\xD7\x01\xC0\x1D\xD0\x02\xD9\x01\xC0\x07\xD0\x01\xC0\x01\xD0\x04\xD8\x02\xDC\x01\xD0\x02\xD8\x03\xDC\x02\xDE\x01\xDC\x02\xDE\x01\xDF\x01\xDE\x01\xDF\x03\xC0\x1B\xE0\x01\xC0\x01\xE0\x03\xC0\x07\xE0\x01\xC0\x02\xE0\x15\xE7\x01\xE0\x1F\xE8\x01\xE0\x0E\xE8\x01\xEC\x01\xE0\x03\xE8\x03\xEC\x01\xEE\x01\xEC\x03\xEE\x02\xEF\x03\xE0\x0D\xF0\x03\xE0\x02\xF0\x1D\xF4\x01\xF0\x07\xF4\x01\xF0\x01\xF4\x02\xF6\x02\xF7\x03\xF0\x03\xF8\x01\xF0\x01\xF8\x16\xFA\x02\xFB\x03\xF8\x01\xFC\x0C\xFD\x03\xFE\x08\xFF\x10\xFE\x07\xFC\x01\xFD\x03\xFC\x0C\xF8\x01\xFB\x03\xFA\x02\xF8\x16\xF0\x05\xF7\x03\xF6\x02\xF4\x02\xF0\x01\xF4\x01\xF0\x07\xF4\x01\xF0\x1D\xE0\x02\xF0\x03\xE0\x0D\xEF\x03\xEE\x02\xEC\x02\xE8\x01\xEE\x01\xEC\x01\xE8\x03\xE0\x03\xEC\x01\xE8\x01\xE0\x0E\xE8\x01\xE0\x1F\xE7\x01\xE0\x15\xC0\x02\xE0\x01\xC0\x07\xE0\x03\xC0\x1D\xDF\x03\xDE\x01\xDF\x01\xDE\x01\xDC\x02\xDE\x01\xDC\x02\xD8\x03\xD0\x02\xDC\x01\xD8\x02\xD0\x04\xC0\x01\xD0\x01\xC0\x07\xD9\x01\xD0\x02\xC0\x1D\xD7\x01\xC06\x80\x01\xC0\x03\x80\x05\xCF\x01\xC0\x1A\x80\x01\xC0\x01\x80\x03\xC0\x06\x80\x02\xC0\x01\x80\x17\xC0\x03\x80=\xBF\x03\xBE\x01\xBF\x01\xBE\x01\xBC\x02\xBE\x01\xBC\x02\xB8\x04\xB0\x01\xBC\x01\xB8\x02\xB0\x01\xB8\x01\xB0\x05\xA0\x06\xBB\x01\xB0\x02\xA0\x01\xB0\x01\xA0\x06\x80\x05\xA0\x01\x80\x0F\xB7\x01\xB0\x01\xA0\x03\x80;\xAF\x01\x80:\0\x01\x80\x01\0\x03\x80\x0E\0\x02\x80\x02\0\x02\x80\x01\0\x0B\x80\x02\0\x1E\x9F\x01\x9E\x01\x88\x01\x80\x1A\0\x03\x80\x05\0\x03\x80\x01\0\x07\x80\x01\0\x0F\x80\x03\0\x01\x80\x01\0;\x80\x01\0\x7F\x7F\x05~\x02|\x01~\x01|\x02x\x01|\x01x\x03|\x01x\x04p\x03x\x01p\x02`\x01p\x01`\x03{\x01x\x01p\x03`\x03p\x01`\x04@\x03`\x03@\x08\0\x01@\x01\0\x03w\x01p\x01`\x04@\x02`\x01@\x04\0\x03@\x03\0\x0D@\x01\0\x1Fo\x01d\x01`\x01@\x02\0\x03@\x01\0w_\x01^\x01L\x01\0\xFD?\x02>\x01\0\x01\x1C\x01\0\xFB\x07\x01\0\xFF"
WaveformGenerator.wave8580_PS_ = unrle "\0\x7F\x03\x01\0?\x01\x01\0?\x0F\x01\0\x7F\x07\x01\0?\x03\x01\0\x1F\x01\x01\0\x1D\x07\x02\x1F\x01\0\x7F\x03\x01\0?\x03\x01\0\x1F\x01\x01\0\x1E\x01\x01\x0F\x01\0?\x01\x01\0?\x17\x01\0?;\x01\0\x1F=\x01\0\x0F>\x01\0\x07?\x01\0\x01\x0C\x01\x1C\x01?\x01\x1E\x01?\x03\0\x7F\x03\x01\0?\x01\x01\0?\x0F\x01\0?\x01\x01\0?\x07\x01\0?\x0B\x01\0\x1F\x0A\x01\0\x0F^\x01\0\x07_\x01\0\x03_\x01\x0C\x01_\x03\0?\x01\x01\0?G\x01\0?C\x01\0\x1Fe\x01\0\x0Fn\x01\0\x07o\x01\0\x01@\x02o\x01@\x01o\x03\0?c\x01\0\x1E@\x01a\x01\0\x07@\x01\0\x03@\x01\0\x01@\x02p\x01\0\x02@\x05p\x01@\x01`\x02w\x01`\x01w\x03\0\x0F@\x01\0\x06@\x01`\x01\0\x01@\x02`\x01@\x01`\x02y\x01\0\x01@\x06`\x01@\x03`\x04x\x01@\x01`\x06x\x01`\x01p\x02x\x01p\x01y\x01{\x02`\x07p\x01`\x03p\x01`\x01p\x02|\x01`\x01p\x06|\x01p\x01x\x02|\x01x\x01|\x02}\x01p\x01x\x06|\x01x\x01|\x02~\x01|\x01~\x03|\x03~\x02\x7F\x03~\x01\x7F\x06\xFF\x01\0\x7F\x03\x01\0?\x01\x01\0?\x8F\x01\0?\x01\x01\0?\x87\x01\0?\x83\x01\0\x1E\x80\x01\x8D\x01\0\x07\x80\x01\0\x03\x80\x01\0\x01\x80\x02\x8E\x01\0\x03\x80\x04\x8F\x01\x80\x03\x9F\x01\x80\x01\x9F\x03\0?\x01\x01\0\x2F\x80\x01\0\x07\x80\x01\0\x03\x80\x01\0\x01\x80\x02\x87\x01\0\x1F\x80\x01\0\x0F\x80\x01\0\x07\x80\x01\0\x03\x80\x04\x83\x01\0\x0F\x80\x01\0\x05\x80\x03\0\x01\x80\x06\x81\x01\x80\x0F\x84\x01\x80\x07\x87\x01\x80\x03\x87\x01\x80\x01\x8F\x01\xAF\x02\0\x0F\x80\x01\0\x07\x80\x01\0\x03\x80\x05\0\x03\x80\x01\0\x02\x80\x02\0\x01\x80\x16\x83\x01\x80\x1F\x81\x01\x80\x0F\xA0\x01\x80\x07\xA0\x01\x80\x03\xA0\x01\x80\x01\xA3\x01\xB7\x02\x80\x1F\xB1\x01\x80\x0F\xB0\x01\x80\x07\xB0\x01\x80\x01\xA0\x02\xB0\x01\xA0\x01\xB8\x01\xB9\x01\xBB\x01\x80\x07\xA0\x01\x80\x03\xA0\x01\x80\x01\xA0\x02\xB8\x01\x80\x01\xA0\x06\xB8\x01\xA0\x01\xB0\x02\xB8\x01\xB0\x01\xBC\x02\xBD\x01\xA0\x01\xB0\x04\xB8\x02\xBC\x01\xB0\x01\xB8\x02\xBC\x01\xB8\x01\xBC\x01\xBE\x02\xB8\x01\xBC\x02\xBE\x01\xBC\x01\xBE\x02\xBF\x01\xBE\x01\xBF\x07\0\x03\x80\x01\0\x03\x80\x01\0\x03\x80\x01\0\x03\x80\x01\0\x01\x80\x07\0\x01\x80\x26\x81\x01\x80?\xC7\x01\x80>\xC0\x01\xC3\x01\x80\x0F\xC0\x01\x80\x07\xC0\x01\x80\x03\xC0\x01\x80\x01\xC0\x02\xC1\x01\x80\x07\xC0\x01\x80\x03\xC0\x0C\xC7\x01\xC0\x03\xC7\x01\xC0\x01\xCF\x03\x80\x1F\xC0\x01\x80\x0F\xC0\x01\x80\x06\xC0\x02\x80\x01\xC0\x06\xC3\x01\x80\x07\xC0\x01\x80\x03\xC0\x01\x80\x01\xC0\x03\x80\x01\xC0\x0E\xC1\x01\xC0\x1D\xC1\x01\xC7\x01\xD7\x01\xC0\x2F\xD0\x01\xC0\x07\xD0\x01\xC0\x03\xD0\x01\xC0\x01\xD0\x01\xD8\x01\xDB\x01\xC0\x0F\xD8\x01\xC0\x07\xD8\x01\xC0\x03\xD8\x01\xD0\x01\xD8\x02\xDD\x01\xC0\x03\xD0\x01\xC0\x01\xD0\x02\xDC\x01\xD0\x01\xD8\x02\xDC\x01\xD8\x01\xDC\x02\xDE\x01\xD8\x01\xDC\x02\xDE\x01\xDC\x01\xDE\x02\xDF\x01\xDE\x01\xDF\x07\xC0?\xE3\x01\xC0\x17\xE0\x01\xC0\x03\xE0\x01\xC0\x01\xE0\x02\xE1\x01\xC0\x07\xE0\x01\xC0\x03\xE0\x05\xC0\x01\xE0\x0C\xE1\x01\xE3\x01\xE7\x01\xC0\x07\xE0\x01\xC0\x03\xE0\x01\xC0\x01\xE0\x03\xC0\x03\xE0\x01\xC0\x01\xE0\x2A\xEB\x01\xE0\x1B\xE8\x01\xE0\x01\xE8\x02\xED\x01\xE0\x07\xEC\x01\xE0\x03\xEC\x01\xE8\x01\xEC\x02\xEE\x01\xE8\x03\xEC\x02\xEE\x02\xEF\x01\xEC\x01\xEF\x07\xE0\x1F\xF0\x01\xE0\x07\xF0\x01\xE0\x03\xF0\x01\xE0\x01\xF0\x03\xE0\x03\xF0\x0C\xF3\x01\xE0\x03\xF0\x1C\xF5\x01\xF0\x0D\xF4\x02\xF6\x01\xF0\x03\xF4\x01\xF0\x01\xF4\x01\xF6\x01\xF7\x01\xF4\x01\xF6\x02\xF7\x05\xF0\x07\xF8\x01\xF0\x05\xF8\x03\xF0\x03\xF8\x01\xF0\x01\xF8\x0A\xF9\x01\xF8\x0F\xFA\x01\xF8\x07\xFB\x01\xF8\x01\xFA\x02\xFB\x05\xF8\x03\xFC\x01\xF8\x01\xFC\x12\xFD\x01\xFC\x03\xFD\x05\xFC\x02\xFE\x0E\xFF\x10"
WaveformGenerator.wave8580_PST = unrle "\0\xFF\0\xFF\0\xFF\0\xFF\0\x03\x1F\x01\0\xFF\0\xFF\0\xFF\0\xF1\x20\x01p\x01`\x01\x20\x01p\x05x\x03|\x02~\x02\x7F\x02\0\xFF\0\xFF\0\xFF\0\xFF\0\x01\x08\x01\x1E\x01?\x01\0\xFF\0\xF8\x80\x07\x8C\x01\x9F\x01\0>\x80\x02\0\x1E\x80\x02\0\x06\x80\x01\0\x03\x80\x16\0\x02\x80\x01\0\x02\x80\x04\0\x01\x80d\xC0\x11\xCF\x01\xC0o\xE0\x01\xC0\x04\xE0\x0B\xE3\x01\xE06\xF0\x24\xF8\x11\xFC\x0A\xFE\x04\xFF\x07"

-- * voice *

local Voice = {}
Voice.__index = Voice

function Voice:new()
    local obj = setmetatable({
        control = 0,
        wave = WaveformGenerator:new(),
        envelope = EnvelopeGenerator:new()
    }, self)
    obj:set_chip_model(chip_model.MOS6581)
    return obj
end

function Voice:set_chip_model(model)
    self.wave:set_chip_model(model)

    if model == chip_model.MOS6581 then
        self.wave_zero = 0x380

        self.voice_DC = 0x7F800
    else
        self.wave_zero = 0x800
        self.voice_DC = 0
    end
end

function Voice:set_sync_source(source)
    self.wave:set_sync_source(source.wave)
end

function Voice:reset()
    self.wave:reset()
    self.envelope:reset()
end

function Voice:writeCONTROL_REG(control)
    self.wave:writeCONTROL_REG(control)
    self.envelope:writeCONTROL_REG(control)
    self.control = control
end

function Voice:output()
    return (self.wave:output() - self.wave_zero)*self.envelope.envelope_counter + self.voice_DC
end

-- * sid *

local SID = {}
SID.__index = SID

function SID:new()
    local obj = setmetatable({
        voice = {[0] = Voice:new(), Voice:new(), Voice:new()},
        filter = Filter:new(),
        extfilt = ExternalFilter:new(),
        envtime = 0,
        wavetime = 0,
        filtertime = 0,
        extfilttime = 0
    }, self)
    obj.sample = 0
    obj.fir = 0

    obj.voice[0]:set_sync_source(obj.voice[2])
    obj.voice[1]:set_sync_source(obj.voice[0])
    obj.voice[2]:set_sync_source(obj.voice[1])

    obj:set_sampling_parameters(985248, sampling_method.SAMPLE_FAST, 48000)

    obj.bus_value = 0
    obj.bus_value_ttl = 0

    obj.ext_in = 0
    return obj
end

function SID:set_chip_model(model)
    for i = 0, 2 do
        self.voice[i]:set_chip_model(model)
    end

    self.filter:set_chip_model(model)
    self.extfilt:set_chip_model(model)
end

function SID:enable_filter(enable)
    self.filter:enable_filter(enable)
end

function SID:enable_external_filter(enable)
    self.extfilt:enable_filter(enable)
end

function SID:set_sampling_parameters(clock_freq, method, sample_freq, pass_freq, filter_scale)
    pass_freq = pass_freq or -1
    filter_scale = filter_scale or 0.97

    if method == sampling_method.SAMPLE_RESAMPLE_INTERPOLATE or method == sampling_method.SAMPLE_RESAMPLE_FAST then
        if SID.FIR_N*clock_freq/sample_freq >= SID.RINGSIZE then
            return false
        end

        if pass_freq < 0 then
            pass_freq = 20000
            if 2*pass_freq/sample_freq >= 0.9 then
                pass_freq = 0.9*sample_freq/2
            end
        elseif pass_freq > 0.9*sample_freq/2 then
            return false
        end

        if filter_scale < 0.9 or filter_scale > 1.0 then
            return false
        end
    end

    self.clock_frequency = clock_freq
    self.sampling = method

    self.cycles_per_sample = floor(clock_freq/sample_freq*2^SID.FIXP_SHIFT + 0.5)

    self.sample_offset = 0
    self.sample_prev = 0

    if method ~= sampling_method.SAMPLE_RESAMPLE_INTERPOLATE and method ~= sampling_method.SAMPLE_RESAMPLE_FAST then
        self.sample = nil
        self.fir = nil
        return true
    end

    local A = -20*log(1/65536, 10)
    local dw = (1 - 2*pass_freq/sample_freq)*pi
    local wc = (2*pass_freq/sample_freq + 1)*pi/2

    local beta = 0.1102*(A - 8.7)
    local I0beta = SID.I0(beta)

    local N = floor((A - 7.95)/(2.285*dw) + 0.5)
    N = N + band(N, 1)

    local f_samples_per_cycle = sample_freq/clock_freq
    local f_cycles_per_sample = clock_freq/sample_freq

    self.fir_N = floor(N*f_cycles_per_sample) + 1
    self.fir_N = bor(self.fir_N, 1)

    local res = method == sampling_method.SAMPLE_RESAMPLE_INTERPOLATE and SID.FIR_RES_INTERPOLATE or SID.FIR_RES_FAST
    local n = ceil(log(res/f_cycles_per_sample, 2))
    self.fir_RES = 2^n

    self.fir = {}

    for i = 0, self.fir_RES-1 do
        local fir_offset = i*self.fir_N + floor(self.fir_N / 2)
        local j_offset = i/self.fir_RES
        for j = -floor(self.fir_N/2), floor(self.fir_N/2) do
            local jx = j - j_offset
            local wt = wc*jx/f_cycles_per_sample
            local temp = jx/(self.fir_N/2)
            local Kaiser = abs(temp) <= 1 and SID.I0(beta*sqrt(1 - temp*temp))/I0beta or 0
            local sincwt = abs(wt) >= 1e-6 and sin(wt)/wt or 1
            local val = 2^SID.FIR_SHIFT*filter_scale*f_samples_per_cycle*wc/pi*sincwt*Kaiser
            self.fir[fir_offset + j] = floor(val + 0.5) % 32768 -- band(val + 0.5, 0xffff)
        end
    end

    if not self.sample then
        self.sample = {}
    end
    for j = 0, SID.RINGSIZE*2-1 do
        self.sample[j] = 0
    end
    self.sample_index = 0

    return true
end

function SID:adjust_sampling_frequency(sample_freq)
    self.cycles_per_sample = floor(self.clock_frequency/sample_freq*2^SID.FIXP_SHIFT + 0.5)
end

function SID:fc_default()
    return self.filter:fc_default()
end

function SID:fc_plotter()
    return self.filter:fc_plotter()
end

function SID:clock_0()
    self.bus_value_ttl = self.bus_value_ttl - 1
    if self.bus_value_ttl <= 0 then
        self.bus_value = 0
        self.bus_value_ttl = 0
    end

    for i = 0, 2 do
        self.voice[i].envelope:clock()
    end

    for i = 0, 2 do
        self.voice[i].wave:clock()
    end

    for i = 0, 2 do
        self.voice[i].wave:synchronize()
    end

    self.filter:clock(self.voice[0]:output(), self.voice[1]:output(), self.voice[2]:output(), self.ext_in)

    self.extfilt:clock(self.filter:output())
end

function SID:clock_1(delta_t)
    if delta_t <= 0 then
        return
    end

    self.bus_value_ttl = self.bus_value_ttl - 1
    if self.bus_value_ttl <= 0 then
        self.bus_value = 0
        self.bus_value_ttl = 0
    end

    --local start = os.epoch "nano"
    for i = 0, 2 do
        self.voice[i].envelope:clock(delta_t)
    end
    --self.envtime = self.envtime + (os.epoch "nano" - start)

    --start = os.epoch "nano"
    local delta_t_osc = delta_t
    while delta_t_osc ~= 0 do
        local delta_t_min = delta_t_osc

        for i = 0, 2 do
            local wave = self.voice[i].wave
            if wave.sync_dest.sync and wave.freq ~= 0 then
                local freq = wave.freq
                local accumulator = wave.accumulator

                local delta_accumulator = (accumulator >= 0x800000 and 0x1000000 or 0x800000) - accumulator

                local delta_t_next = floor(delta_accumulator / freq)
                if delta_accumulator % freq ~= 0 then
                    delta_t_next = delta_t_next + 1
                end

                if delta_t_next < delta_t_min then
                    delta_t_min = delta_t_next
                end
            end
        end

        for i = 0, 2 do
            self.voice[i].wave:clock(delta_t_min)
        end

        for i = 0, 2 do
            self.voice[i].wave:synchronize()
        end

        delta_t_osc = delta_t_osc - delta_t_min
    end
    --self.wavetime = self.wavetime + (os.epoch "nano" - start)

    --start = os.epoch "nano"
    self.filter:clock(delta_t, self.voice[0]:output(), self.voice[1]:output(), self.voice[2]:output(), self.ext_in)
    --self.filtertime = self.filtertime + (os.epoch "nano" - start)

    --start = os.epoch "nano"
    self.extfilt:clock(delta_t, self.filter:output())
    --self.extfilttime = self.extfilttime + (os.epoch "nano" - start)
end

function SID:clock_5(delta_t, buf, start, n, interleave)
    interleave = interleave or 1

    if self.sampling == sampling_method.SAMPLE_INTERPOLATE then
        return self:clock_interpolate(delta_t, buf, start, n, interleave)
    elseif self.sampling == sampling_method.SAMPLE_RESAMPLE_INTERPOLATE then
        return self:clock_resample_interpolate(delta_t, buf, start, n, interleave)
    elseif self.sampling == sampling_method.SAMPLE_RESAMPLE_FAST then
        return self:clock_resample_fast(delta_t, buf, start, n, interleave)
    else
        return self:clock_fast(delta_t, buf, start, n, interleave)
    end
end

function SID:clock(a, b, c, d, e)
    if b then return self:clock_5(a, b, c, d, e)
    elseif a then return self:clock_1(a)
    else return self:clock_0() end
end

function SID:reset()
    for i = 0, 2 do
        self.voice[i]:reset()
    end
    self.filter:reset()
    self.extfilt:reset()

    self.bus_value = 0
    self.bus_value_ttl = 0
end

function SID:read(offset)
    if offset == 0x19 or offset == 0x1a then return 0
    elseif offset == 0x1b then return self.voice[2].wave:readOSC()
    elseif offset == 0x1c then return self.voice[2].envelope:readENV()
    else return self.bus_value end
end

local SID_write_table = {
    [0] = function(self, v) return self.voice[0].wave:writeFREQ_LO(v) end,
    function(self, v) return self.voice[0].wave:writeFREQ_HI(v) end,
    function(self, v) return self.voice[0].wave:writePW_LO(v) end,
    function(self, v) return self.voice[0].wave:writePW_HI(v) end,
    function(self, v) return self.voice[0]:writeCONTROL_REG(v) end,
    function(self, v) return self.voice[0].envelope:writeATTACK_DECAY(v) end,
    function(self, v) return self.voice[0].envelope:writeSUSTAIN_RELEASE(v) end,
    function(self, v) return self.voice[1].wave:writeFREQ_LO(v) end,
    function(self, v) return self.voice[1].wave:writeFREQ_HI(v) end,
    function(self, v) return self.voice[1].wave:writePW_LO(v) end,
    function(self, v) return self.voice[1].wave:writePW_HI(v) end,
    function(self, v) return self.voice[1]:writeCONTROL_REG(v) end,
    function(self, v) return self.voice[1].envelope:writeATTACK_DECAY(v) end,
    function(self, v) return self.voice[1].envelope:writeSUSTAIN_RELEASE(v) end,
    function(self, v) return self.voice[2].wave:writeFREQ_LO(v) end,
    function(self, v) return self.voice[2].wave:writeFREQ_HI(v) end,
    function(self, v) return self.voice[2].wave:writePW_LO(v) end,
    function(self, v) return self.voice[2].wave:writePW_HI(v) end,
    function(self, v) return self.voice[2]:writeCONTROL_REG(v) end,
    function(self, v) return self.voice[2].envelope:writeATTACK_DECAY(v) end,
    function(self, v) return self.voice[2].envelope:writeSUSTAIN_RELEASE(v) end,
    function(self, v) return self.filter:writeFC_LO(v) end,
    function(self, v) return self.filter:writeFC_HI(v) end,
    function(self, v) return self.filter:writeRES_FILT(v) end,
    function(self, v) return self.filter:writeMODE_VOL(v) end,
}

function SID:write(offset, value)
    self.bus_value = value
    self.bus_value_ttl = 0x2000

    local f = SID_write_table[offset]
    if f then return f(self, value) end
end

function SID:read_state()
    local state = SID.State:new()
    local j = 0
    for i = 0, 2 do
        local wave = self.voice[i].wave
        local envelope = self.voice[i].envelope
        state.sid_register[j + 0] = band(wave.freq, 0xff)
        state.sid_register[j + 1] = rshift(wave.freq, 8)
        state.sid_register[j + 2] = band(wave.pw, 0xff)
        state.sid_register[j + 3] = rshift(wave.pw, 8)
        state.sid_register[j + 4] = bor(
            lshift(wave.waveform, 4),
            wave.test and 0x08 or 0,
            wave.ring_mod and 0x04 or 0,
            wave.sync and 0x02 or 0,
            envelope.gate and 0x01 or 0
        )
        state.sid_register[j + 5] = bor(lshift(envelope.attack, 4), envelope.decay)
        state.sid_register[j + 6] = bor(lshift(envelope.sustain, 4), envelope.release)
        j = j + 7
    end

    state.sid_register[j + 0] = band(self.filter.fc, 0x007)
    state.sid_register[j + 1] = rshift(self.filter.fc, 3)
    state.sid_register[j + 2] = bor(lshift(self.filter.res, 4), self.filter.filt)
    state.sid_register[j + 3] = bor(
        self.filter.voice3off and 0x80 or 0,
        lshift(self.filter.hp_bp_lp, 4),
        self.filter.vol
    )
    j = j + 4

    while j < 0x1d do
        state.sid_register[j] = self:read(j)
        j = j + 1
    end
    while j < 0x20 do
        state.sid_register[j] = 0
        j = j + 1
    end

    state.bus_value = self.bus_value
    state.bus_value_ttl = self.bus_value_ttl

    for i = 0, 2 do
        state.accumulator[i] = self.voice[i].wave.accumulator
        state.shift_register[i] = self.voice[i].wave.shift_register
        state.rate_counter[i] = self.voice[i].envelope.rate_counter
        state.rate_counter_period[i] = self.voice[i].envelope.rate_period
        state.exponential_counter[i] = self.voice[i].envelope.exponential_counter
        state.exponential_counter_period[i] = self.voice[i].envelope.exponential_counter_period
        state.envelope_counter[i] = self.voice[i].envelope.envelope_counter
        state.envelope_state[i] = self.voice[i].envelope.state
        state.hold_zero[i] = self.voice[i].envelope.hold_zero
    end

    return state
end

function SID:write_state(state)
    for i = 0, 0x18 do
        self:write(i, state.sid_register[i])
    end

    self.bus_value = state.bus_value
    self.bus_value_ttl = state.bus_value_ttl

    for i = 0, 2 do
        self.voice[i].wave.accumulator = state.accumulator[i]
        self.voice[i].wave.shift_register = state.shift_register[i]
        self.voice[i].envelope.rate_counter = state.rate_counter[i]
        self.voice[i].envelope.rate_period = state.rate_counter_period[i]
        self.voice[i].envelope.exponential_counter = state.exponential_counter[i]
        self.voice[i].envelope.exponential_counter_period = state.exponential_counter_period[i]
        self.voice[i].envelope.envelope_counter = state.envelope_counter[i]
        self.voice[i].envelope.state = state.envelope_state[i]
        self.voice[i].envelope.hold_zero = state.hold_zero[i]
    end
end

function SID:input(sample)
    self.ext_in = lshift(sample, 4)*3
end

function SID:output(bits)
    if not bits then return min(max(floor(self.extfilt:output()/11), -0x8000), 0x7fff) end
    local range = 2^bits
    local half = rshift(range, 1)
    local sample = floor(self.extfilt:output()/floor(734220/range))
    if sample >= half then
        return half - 1
    end
    if sample < -half then
        return -half
    end
    return sample
end

function SID.I0(x)
    local I0e = 1e-6

    local sum, u, halfx, temp, n = 1, 1, x / 2, nil, 1

    repeat
        temp = halfx/n
        n = n + 1
        u = u * temp * temp
        sum = sum + u
    until u < I0e*sum

    return sum
end

-- returns s, delta_t
function SID:clock_fast(delta_t, buf, start, n, interleave)
    local s = 0

    while true do
        local next_sample_offset = self.sample_offset + self.cycles_per_sample + 0x8000 -- 2^(SID.FIXP_SHIFT-1)
        local delta_t_sample = rshift(next_sample_offset, SID.FIXP_SHIFT)
        if delta_t_sample > delta_t then
            break
        end
        if s >= n then
            return s, delta_t
        end
        self:clock(delta_t_sample)
        delta_t = delta_t - delta_t_sample
        self.sample_offset = band(next_sample_offset, SID.FIXP_MASK) - 0x8000 --2^(SID.FIXP_SHIFT-1)
        buf[start+s*interleave] = self:output()
        s = s + 1
    end

    self:clock(delta_t)
    self.sample_offset = self.sample_offset - lshift(delta_t, SID.FIXP_SHIFT)
    return s, 0
end

function SID:clock_interpolate(delta_t, buf, start, n, interleave)
    local s = 0

    while true do
        local next_sample_offset = self.sample_offset + self.cycles_per_sample
        local delta_t_sample = rshift(next_sample_offset, SID.FIXP_SHIFT)
        if delta_t_sample > delta_t then
            break
        end
        if s >= n then
            return s, delta_t
        end
        for i = 1, delta_t_sample - 1 do
            self:clock()
        end
        if delta_t_sample >= 0 then
            self.sample_prev = self:output()
            self:clock()
        end

        delta_t = delta_t - delta_t_sample
        self.sample_offset = band(next_sample_offset, SID.FIXP_MASK)

        local sample_now = self:output()
        buf[start+s*interleave] = (self.sample_prev + rshift(self.sample_offset*(sample_now - self.sample_prev), SID.FIXP_SHIFT)) % 32768
        self.sample_prev = sample_now
    end

    for i = 1, delta_t - 1 do
        self:clock()
    end
    if delta_t >= 0 then
        self.sample_prev = self:output()
        self:clock()
    end
    self.sample_offset = self.sample_offset - lshift(delta_t, SID.FIXP_SHIFT)
    return s, 0
end

function SID:clock_resample_interpolate(delta_t, buf, start, n, interleave)
    error("Unimplemented")
end

function SID:clock_resample_fast(delta_t, buf, start, n, interleave)
    error("Unimplemented")
end

SID.FIR_N = 125
SID.FIR_RES_INTERPOLATE = 285
SID.FIR_RES_FAST = 51473
SID.FIR_SHIFT = 15
SID.RINGSIZE = 16384

SID.FIXP_SHIFT = 16
SID.FIXP_MASK = 0xffff

SID.State = {}
SID.State.__index = SID.State

function SID.State:new()
    local obj = setmetatable({
        sid_register = {},
        accumulator = {},
        shift_register = {},
        rate_counter = {},
        rate_counter_period = {},
        exponential_counter = {},
        exponential_counter_period = {},
        envelope_counter = {},
        envelope_state = {},
        hold_zero = {}
    }, self)
    for i = 0, 0x1f do
        obj.sid_register[i] = 0
    end

    obj.bus_value = 0
    obj.bus_value_ttl = 0

    for i = 0, 2 do
        obj.accumulator[i] = 0
        obj.shift_register[i] = 0x7ffff8
        obj.rate_counter[i] = 0
        obj.rate_counter_period[i] = 9
        obj.exponential_counter[i] = 0
        obj.exponential_counter_period[i] = 1
        obj.envelope_counter[i] = 0
        obj.envelope_state[i] = EnvelopeGenerator.State.RELEASE
        obj.hold_zero[i] = true
    end
    return obj
end

SID.chip_model = chip_model
SID.sampling_method = sampling_method
SID._VERSION = "5.0.0"

return SID
