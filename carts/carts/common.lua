-- highest integer value in pico
c_int_min=-32768
c_int_max=32767
c_float_min=-32768.0
c_float_max=32767.99999

--vector2 class
vec2_meta = {__index=vec2}
vec2={x=0,y=0}
function vec2.new(o)
    o = o or {} 
    self.__index=self
    setmetatable(o,self)
    return o
end