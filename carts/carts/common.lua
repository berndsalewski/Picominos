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

--prints the content of a 1-based integer index table
--does not extract table values
function print_array(t,x,y,col)
    if(t==nil)return 
	local out = "{"
	for val in all(t) do
        if type(val) == "table" then
            out=out.."table,"
        else
            out=out..val..","
        end
	end
	out=sub(out,1,#out-1).."}"
	print(out,50,50,col)
end

--enum for color values
e_colors={
    pitchblue=0,darkblue=1,purple=2,earthlygreen=3,
    brickbrown=4,mudbrown=5,lightgray=6,white=7,
    red=8,orange=9,yellow=10,green=11,
    blue=12,violet=13,pink=14,peach=15
}
e_buttons={left=0,right=1,up=2,down=3,o=4,x=5}