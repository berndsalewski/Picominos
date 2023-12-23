hs={
    current_selected_char=1,
    current_edit_index=1,
    current_editable_name="a",
    is_highscore_achieved=false,
    on_confirmed=nil,
    score_full_width=6*c_char_width+5,
    -- highscore_data is saved in cartridge data
    -- indices 0-19
    -- 0=1st name, 1=1st score, ..., 18=10th name, 19=10th score 
    highscore_data=nil,
    support_32=true,
    score="",
    score_32=0
}

-- 31 different chars possible (2ょ●6)
-- 0|32 for end of string
hs.encoding_table = {
	a=1,b=2,c=3,d=4,e=5,f=6,g=7,
	h=8,i=9,j=10,k=11,l=12,m=13,
	n=14,o=15,p=16,q=17,r=18,
	s=19,t=20,u=21,v=22,w=23,
	x=24,y=25,z=26,["<"]=27,["_"]=28,
    ["-"]=29,["+"]=30,["|"]=31,
}

hs.decoding_table = {
	"a","b","c","d","e","f","g","h",
	"i","j","k","l","m","n","o","p","q",
	"r","s","t","u","v","w","x","y","z",
	"<","_","-","+","|"
}

function hs:init()
    self:read_highscore_from_cartrige()
    self:reset()
end

function hs:reset()
    self.current_editable_name={"a"}
    self.current_selected_char=1
    self.current_edit_index=1	
end

function hs:update()
    if btnp(e_buttons.up) then
		self.current_selected_char=wrap_value(self.current_selected_char+1,1,#self.decoding_table)
		self.current_editable_name[self.current_edit_index]=self.decoding_table[self.current_selected_char]
	elseif btnp(e_buttons.down) then
		self.current_selected_char=wrap_value(self.current_selected_char-1,1,#self.decoding_table)
		self.current_editable_name[self.current_edit_index]=self.decoding_table[self.current_selected_char]
	elseif btnp(e_buttons.left) then
		self.current_edit_index=max(self.current_edit_index-1,1)
		if #self.current_editable_name>self.current_edit_index then
			self.current_editable_name[self.current_edit_index+1]=nil
		end
	elseif btnp(e_buttons.right) then
		self.current_edit_index=min(self.current_edit_index+1,6)
		self.current_selected_char=self.encoding_table["a"]
		if(self.current_edit_index>#self.current_editable_name)then
			self.current_editable_name[self.current_edit_index]="a"
		end
	elseif btnp(e_buttons.x) then
		self:save_highscore(self:get_name(),self.score_32)
        self:on_confirmed()		
	end
end

-- draws the highscore table in display-only mode
function hs:draw_highscore(x,y)
	color(7)
	local char_height=7
	for i=1,#self.highscore_data do
		local temp_y=y+(i-1)*char_height
		local token=". "
		if(i>=10) token="."
		if self.highscore_data[i].score_32==0 then 
			print(i..token,x,temp_y)
		else
			print(i..token..self.highscore_data[i].name,x,temp_y)
            local score_width=print(tostr(self.highscore_data[i].score_32,0x2),0,-20)
			print(tostr(self.highscore_data[i].score_32,0x2),x+38+self.score_full_width-score_width,temp_y)
		end
	end	
end

-- draws the highscore table in edit mode
function hs:edit_highscore(x,y)
	color(e_colors.white)
	local is_score_inserted=false
	local char_width=4
	local char_height=7
	local active_letter_x=x+(3*char_width)+(self.current_edit_index-1)*char_width
	
	for i=1,#self.highscore_data do
		local temp_y=y+(i-1)*char_height
		local token=". "
		if(i>=10) token="."
		if not is_score_inserted and self.score_32 > self.highscore_data[i].score_32 then
			rectfill(active_letter_x,temp_y,active_letter_x+char_width-2,temp_y+5,e_colors.red)
			color(e_colors.white)
			print(i..token,x,temp_y)
			print(self:get_name(),x+12,temp_y)
            local score_width=print(self.score,0,-20)
			print(self.score,x+38+self.score_full_width-score_width,temp_y)
			is_score_inserted=true
		elseif self.highscore_data[i+(is_score_inserted and -1 or 0)].score_32==0 then 
			print(i..token,x,temp_y)
		else 
			print(i..token..self.highscore_data[i+(is_score_inserted and -1 or 0)].name,x,temp_y)
			local highscore_32 = self.highscore_data[i+(is_score_inserted and -1 or 0)].score_32
            local highscore=tostr(highscore_32,0x2)
            local score_width=print(highscore,0,-20)
			print(highscore,x+38+self.score_full_width-score_width,temp_y)
		end
	end	
end

function hs:read_highscore_from_cartrige()
	self.highscore_data={}
	for i=0,19,2 do
		local name = self:decode_name(dget(i)) -- decode to string
		local score_32 = dget(i+1)
		add(self.highscore_data,{name=name,score_32=score_32})
	end
end

function hs:send_score(score)
    self.score=score
    self.score_32=tonum(score,0x2)
    self.is_highscore_achieved=self:is_highscore(self.score_32) 
end

function hs:get_name()
	local out=""
	for char in all(self.current_editable_name) do
		out=out..char
	end
	return out
end

function hs:save_highscore(name, score_32)	
	-- find index at which new score is added
	local score_index
	for i=1,#self.highscore_data do
		if(score_32 > self.highscore_data[i].score_32) then
			score_index = i
			break
		end
	end

	if score_index ~= nil then
		add(self.highscore_data,{name=name,score_32=score_32},score_index)
		deli(self.highscore_data)
		self:write_highscore_to_cartrige()
	end
end

function hs:write_highscore_to_cartrige()
	for i=1,#self.highscore_data do
		dset((i-1)*2,self:encode_name(self.highscore_data[i].name))
		dset(((i-1)*2)+1,self.highscore_data[i].score_32)
	end
end

--number to string
--64=...0100.0000 >>>5 -> x0000010=2
--encoded is a 32bit value
--64 -> 0x0040.0000 -> binary: 0000 0000 0010 0000 0000 0000 0000 0000
function hs:decode_name(encoded)
	local word_length=6 --6*5=30bits
	local char_index=0
	local max_char_bits=5
	local decoded=""
	local val
	for i=1,word_length do
		-- shift current char to the right
		val = encoded >>> (i-1)*max_char_bits
		if val == 0 then break end --end of data
		--get the first 5 bits with bitmask, 31 ->...00000 11111
		val = (val & (31>>>16)) 
		--and convert int32 to num16.16
		val = val << 16
		-- lookup char for value
		local char = self.decoding_table[val]
		-- and concatenate 
		decoded=decoded..char
	end
	return decoded
end

-- string -> number
-- characters are encoded as numerical values
-- every char is encoded with 5 bits (31 chars possible) 
-- max chars per name -> 6 (x5=30bits)
-- first char at most right position of ("artur" is stored as "rutra")
-- "abc" becomes
--						c	  b 	a
-- 00 00000 00000 00000 00011 00010 00001
function hs:encode_name(name)
	name=split(name,"")
	local char_index=0
	local word_length=6
	local encoded=0.0
	local max_char_bits=5
	for char in all(name) do
		local num = self.encoding_table[char]
		 --convert to 32bit integer by removing the fractional bits 
		num = num >>> 16
		--move the bits to the correct position in a 32bit array
		num = num << (char_index * max_char_bits) 
		encoded = encoded | num	
		char_index+=1
	end
	return encoded
end

-- erases all data permanently
function hs:erase_all_highscores()
	for i=0,19 do
		dset(i,0)
	end
	self:read_highscore_from_cartrige()
end

function hs:is_highscore(score_32)
	return score_32>self.highscore_data[#self.highscore_data].score_32
end