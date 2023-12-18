pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
#include common.lua
cart_id="picotris"

e_game_states={none=0,start=1,game=2,game_over=3, game_over_screen=4}
game_state=e_game_states.none

-- highscore is saved in cartridge data
-- indices 0-19
-- 0=1st name, 1=1st score, ..., 18=10th name, 19=10th scoregit 
highscore=nil

function _init()
	game_state=e_game_states.start
	cartdata(cart_id)
	read_highscore_from_cartrige()
end

function _update60()
	if game_state==e_game_states.start then
		game_start.update()
	elseif game_state==e_game_states.game then
		game_running.update()
	elseif game_state==e_game_states.game_over_screen then
		game_over_screen.update()	
	end
end

--30fps or 15fps
--60fps with update60
function _draw()
	cls()
	rect(0,0,127,127,5)
	if game_state==e_game_states.start then
		game_start.draw()
	elseif game_state==e_game_states.game then
		game_running.draw()
	elseif game_state==e_game_states.game_over then
		game_over.draw()
	elseif game_state==e_game_states.game_over_screen then
		game_over_screen.draw()
	end
end

-->8
--game_start
--==============================
game_start={}
function game_start.update()
	if btnp(5) then
		init_game_state()
		game_state=e_game_states.game
	end
end

function game_start.draw()
	rectfill(1,1,126,7,1)
	print("picotris",2,2,6)
	line(1,9,126,9,5)
	line(1,8,126,8,6)
	draw_highscore_read(34,27)
	print("❎".."start game",40,100,6)
	print("⬅️".."left|".."➡️".."right",2,109,5)
	print("⬇️".."fast drop",2,115)
	print("🅾️".."rotate left|".."❎".."rotate right",2,121)
end

-->8
--game_running
--==============================
--config
c_cells_hor=10
c_cells_vert=20
c_cell_size=6
c_grid_h=c_cells_vert*c_cell_size
c_grid_w=c_cells_hor*c_cell_size
c_grid_x=64-c_grid_w/2-18
c_grid_y=4

--[[
stores all minos
1-indexed but coordinates are 
0-indexed
	1	2	3
1	0,0	1,0	2,0
2	0,1	1,1	2,1
3	0,2	1,2	2,2
]]
matrix={}

e_mino_types={none=0,i=1,l=2,o=3,s=4,z=5,t=6,j=7}
e_mino_directions={n=1,e=2,s=3,w=4}

-- the mino controlled by the player
mino={
	pos=nil, -- 4 xy coordinates
	typ=e_mino_types.none,
	rot=e_mino_directions.n
}
-- rotation matrices 
-- 1=n>e,2=e>s,3=s>w,4=w>n
c_mino_rotations={
	{--i
		{1,-2,0,-1,-1,0,-2,1},
		{2,2,1,1,0,0,-1,-1},
		{-2,1,-1,0,0,-1,1,-2},
		{-1,-1,0,0,1,1,2,2}
	},
	{--l
		{1,-1,0,0,-1,1,0,-2},
		{1,1,0,0,-1,-1,2,0},
		{-1,1,0,0,1,-1,0,2},
		{-1,-1,0,0,1,1,-2,0}
	},
	{--o
		{1,0,0,1,-1,0,0,-1},
		{0,1,-1,0,0,-1,1,0},
		{-1,0,0,-1,1,0,0,1},
		{0,-1,1,0,0,1,-1,0}
	},
	{--s
		{0,0,-1,1,0,-2,-1,-1},
		{0,1,-1,0,2,1,1,0},
		{-1,-1,0,-2,-1,1,0,0},
		{1,0,2,1,-1,0,0,1}
	},
	{--z
		{1,-1,0,0,-1,-1,-2,0},
		{1,2,0,1,1,0,0,-1},
		{-2,0,-1,-1,0,0,1,-1},
		{0,-1,1,0,0,1,1,2}
	},
	{--t
		{1,-1,0,0,-1,1,-1,-1},
		{1,1,0,0,-1,-1,1,-1},
		{-1,1,0,0,1,-1,1,1},
		{-1,-1,0,0,1,1,-1,1}
	},
	{--j
		{1,-1,0,0,-1,1,-2,0},
		{1,1,0,0,-1,-1,0,-2},
		{-1,1,0,0,1,-1,2,0},
		{-1,-1,0,0,1,1,0,2}
	}
}

--initial spawn positions
--a mino is a sequence of 4 x,y vectors
c_mino_spawn_positions={
	{3,2,4,2,5,2,6,2},--i
	{3,2,4,2,5,2,3,3},--l
	{4,2,5,2,5,3,4,3},--o
	{4,2,5,2,3,3,4,3},--s
	{3,2,4,2,4,3,5,3},--z
	{3,2,4,2,5,2,4,3},--t
	{3,2,4,2,5,2,5,3}--j
}

--could be a class but since we only need 1
bag={
	content={}
}
function bag:get_next()
	local next=deli(self.content,#self.content)
	if(#self.content==0)self:fill(self)
	return next
end
function bag:fill()
	local types={1,2,3,4,5,6,7}
	self.content={}
	for i=1,#types do
		local n=rnd(types)
		del(types,n)
		add(self.content,n)
	end
end
--[[ for debugging
function bag:print()
	out=""
	for i=1,#self.content do
		out=out..self.content[i]..","
	end
	print(out)
end
]]

-- game variables & constants
c_max_level=19
c_line_score_factor={40,100,300,1200}
cleared_lines=0
level=0
score=0
-- soft dropping
softdrop_line_count=0
is_softdropping=false
is_btn_down_pressed=false
-- how many frames pass before 1 cell move -> 1/3G
c_softdrop_speed=3
-- drop speed per level defined as frame count between drops 
c_mino_drop_speeds={53,49,45,41,37,33,28,22,17,11,10,9,8,7,6,6,5,5,4,4,3}
-- frames since game start
frame_count=0
-- the last frame when the mino was dropped
last_drop_frame=0

-- ARE entry delay see: https://tetris.wiki/c_are
c_are=2 
frames_since_lock=0

c_line_clear_delay=93
frames_since_clear=0
-- was at least 1 line cleared with the last drop?
is_line_cleared=false
lines_to_clear={}

game_running={}
function game_running.update()
	if frame_count==c_int_max then
		frame_count=frame_count-last_drop_frame
		last_drop_frame=0
	end

	frame_count+=1
	
	if mino.pos==nil then
		if is_line_cleared then
			frames_since_clear+=1
			if frames_since_clear==c_line_clear_delay then
				remove_cleared_lines()
				blink_framecount=0
				spawn_mino()
				is_line_cleared=false
				frames_since_clear=0
			end
		elseif frames_since_lock==c_are then
			spawn_mino()
			frames_since_lock=0
		else 
			frames_since_lock+=1
		end
	end

	if(btnp(0))move_mino({x=-1,y=0})
	if(btnp(1))move_mino({x=1,y=0})
	if not is_btn_down_pressed and btn(3) then
		is_softdropping=true
		is_btn_down_pressed=true
	end
	if is_btn_down_pressed and not btn(3) then
		is_softdropping=false
		is_btn_down_pressed=false
	end
	if(btnp(4))rotate_mino("ccv")
	if(btnp(5))rotate_mino("cv")
	
	if is_softdropping then
		if frame_count-last_drop_frame >= c_softdrop_speed then
			move_mino({x=0,y=1})
			last_drop_frame=frame_count
		end
	-- auto drop
	elseif frame_count-last_drop_frame >= c_mino_drop_speeds[level+1] then
		move_mino({x=0,y=1})
		last_drop_frame=frame_count
	end
end

function game_running.draw()
	draw_grid()
	draw_matrix()
	draw_game_ui()
	draw_mino()
end

-- dir: {x,y}
function move_mino(dir)
	if(mino.pos==nil)return
	
	local locked=false
	local valid_move

	for i=1,7,2 do
		local new_x=mino.pos[i]+dir.x
	 	local new_y=mino.pos[i+1]+dir.y
	 	valid_move=is_on_grid(new_x,new_y) and is_empty_cell(new_x,new_y)
		if 	not valid_move 
			and dir.y==1	
			and (new_y>=c_cells_vert or not is_empty_cell(new_x,new_y)) then 
			locked=true 
		end
		if(not valid_move) break 
	end

	if valid_move then
		for j=1,7,2 do
			mino.pos[j]=mino.pos[j]+dir.x
			mino.pos[j+1]=mino.pos[j+1]+dir.y
		end
		if(is_softdropping)softdrop_line_count+=1
	end

	if locked then
		for i=1,7,2 do
			local v1=mino.pos[i]+1
			local v2=mino.pos[i+1]+1
			matrix[v1][v2]=mino.typ
		end

		score+=softdrop_line_count
		softdrop_line_count=0

		for y=c_cells_vert,1,-1 do
			for x=1,c_cells_hor do
				if matrix[x][y] == 0 then
					break;
				end

				if x==c_cells_hor then
					--remove this row
					add(lines_to_clear,y)
				end
			end
		end
		if #lines_to_clear>0 then
			cleared_lines+=#lines_to_clear
			local new_level=cleared_lines\10 --integer division
			if(new_level~=level and new_level<=c_max_level)level=new_level
			score+=c_line_score_factor[#lines_to_clear]*(level+1)
			is_line_cleared=true
		end
		is_softdropping=false
		last_drop_frame=frame_count
		mino.pos=nil
	end
end

function spawn_mino()
	mino.rot=e_mino_directions.n
	mino.pos={}
	mino.typ=bag:get_next()
	for v in all(c_mino_spawn_positions[mino.typ])do
		add(mino.pos,v)
	end
	for i=1,7,2 do
		local x=mino.pos[i]
		local y=mino.pos[i+1]
		if matrix[x][y] ~= 0 then
			game_state=e_game_states.game_over
		end
	end 
end

function rotate_mino(dir)
	local rot_valid=true
	local new_mino={}
	if dir=="cv" then
		for i=1,#mino.pos do
			local new_pos=mino.pos[i]+c_mino_rotations[mino.typ][mino.rot][i]
			if i%2==0 then -- y pos
				if new_pos<0 or new_pos>=c_cells_vert then
					rot_valid=false
					break
				end		
			else -- x pos
				if new_pos<0 or new_pos>=c_cells_hor then
					rot_valid=false
					break
				end	
			end	
			new_mino[i]=new_pos
		end--end of loop
		if rot_valid then
			mino.rot=mino.rot%4+1
			mino.pos=new_mino
		end
	elseif dir=="ccv" then
		local next_cur_rot
		for i=1,#mino.pos do
			next_cur_rot=mino.rot-1
			if(next_cur_rot==0)next_cur_rot=4
			local new_pos=mino.pos[i]-c_mino_rotations[mino.typ][next_cur_rot][i]
			if i%2==0 then
				if new_pos<0 or new_pos>=c_cells_vert then
					rot_valid=false
					break
				end		
			else
				if new_pos<0 or new_pos>=c_cells_hor then
					rot_valid=false
					break
				end	
			end	
			new_mino[i]=new_pos
		end--end of loop	
		if rot_valid then	
			mino.rot=next_cur_rot
			mino.pos=new_mino
		end
	end
end

c_blink_rate=20
blink_framecount=0
function draw_matrix()
	if(#lines_to_clear>0)blink_framecount+=1
	for x=1,c_cells_hor do
		for y=1,c_cells_vert do
			local draw=true
			if #lines_to_clear>0 then
				for i=1,#lines_to_clear do
					if lines_to_clear[i]==y and blink_framecount%c_blink_rate>0 and blink_framecount%c_blink_rate<11 then
						--dont draw cell
						draw=false
					end
				end
			end
			if matrix[x][y]>0 and draw then
				draw_cell(x-1,y-1,matrix[x][y])
			end
		end
	end
end

-- x an y are matrix coordinates
function draw_cell(x,y,spr_idx)
	local x1=c_grid_x+x*c_cell_size
	local y1=c_grid_y+y*c_cell_size
	spr(spr_idx,x1,y1)
end

function draw_mino()
	if mino.pos==nil then return end	
	for i=1,7,2 do
		spr(mino.typ,
			c_grid_x+mino.pos[i]*c_cell_size,
			c_grid_y+mino.pos[i+1]*c_cell_size)
	end
end

function draw_next_mino(type,x,y)
	rect(x,y,x+27,y+15)	
	for i=1,7,2 do
		spr(type,
			-16+x+c_mino_spawn_positions[type][i]*c_cell_size,
			-10+y+c_mino_spawn_positions[type][i+1]*c_cell_size)
	end
end

function init_game_state()
	bag:fill()
	lines=0
	level=0
	score=0
	init_matrix()
	frame_count=0
	last_drop_frame=0
end

function init_matrix()
	for x=1,c_cells_hor do
		matrix[x]={}
		for y=1,c_cells_vert do
			matrix[x][y]=0
		end
	end
end

function remove_cleared_lines()
	for y in all(lines_to_clear) do
		for x=1,c_cells_hor do
			matrix[x][y]=0
		end
	end
	--gravity kicks in
	local i=0
	for v in all(lines_to_clear) do
		for y=v-1+i,1,-1 do
			for x=1,c_cells_hor do
				matrix[x][y+1]=matrix[x][y]
			end
		end
		i+=1
	end
	lines_to_clear={}
end

function is_on_grid(x,y)
	return x>=0 and x<c_cells_hor and y>=0 and y<c_cells_vert
end

function is_empty_cell(x,y)
	if(x==-1)x=0
	if(x==c_cells_hor)x=c_cells_hor-1
	if(y==-1)y=0
	if(y==c_cells_vert)y=c_cells_vert-1
	return matrix[x+1][y+1]==0 
end

-->8
--game_over
--==============================
game_over={}
function game_over.draw()
	draw_grid()
	draw_matrix()
	draw_game_ui()
	draw_game_over_matrix()
end

--TODO modularise variables by making them table members
pointer=0
finished=false
max_cells=c_cells_vert*c_cells_hor
cells={}
function draw_game_over_matrix()
	for i=0, pointer do
		local x=i%c_cells_hor 
		local y=(c_cells_vert-1)-i\c_cells_hor
		if(cells[i]==nil)cells[i]=rnd(7)+1 
		draw_cell(x,y,cells[i])
	end

	finished=pointer==max_cells-1
	
	if finished then
		is_highscore_achieved=is_highscore(score) 
		game_state=e_game_states.game_over_screen
		return
	end

	pointer+=1
end

function reset_game_over_matrix()
	cells={}
	finished=false
	pointer=0
end

-->8
--game_over_screen
--==============================
game_over_screen={}
current_selected_char=1
current_edit_index=1
current_editable_name="a"
--is_highscore_editable=false
is_game_over_screen_initialised=false

function game_over_screen.init()
	current_editable_name={"a"}
	current_selected_char=1
	current_edit_index=1	
	is_game_over_screen_initialised=true
end

function game_over_screen.update()
	if not is_game_over_screen_initialised then 
		game_over_screen.init()
	end

	if btnp(e_buttons.up) then
		current_selected_char=wrap_value(current_selected_char+1,1,#decode)
		current_editable_name[current_edit_index]=decode[current_selected_char]
	elseif btnp(e_buttons.down) then
		current_selected_char=wrap_value(current_selected_char-1,1,#decode)
		current_editable_name[current_edit_index]=decode[current_selected_char]
	elseif btnp(e_buttons.left) then
		current_edit_index=max(current_edit_index-1,1)
		if #current_editable_name>current_edit_index then
			current_editable_name[current_edit_index+1]=nil
		end
	elseif btnp(e_buttons.right) then
		current_edit_index=min(current_edit_index+1,6)
		current_selected_char=encode["a"]
		if(current_edit_index>#current_editable_name)then
			current_editable_name[current_edit_index]="a"
		end
	elseif btnp(e_buttons.x) then
		save_highscore(get_name(),score)
		--is_highscore_editable=false
		reset_game_over_matrix()
		game_state=e_game_states.start
		is_game_over_screen_initialised=false
	end

end

function game_over_screen.draw()
	draw_grid()
	draw_matrix()
	draw_game_ui()
	draw_game_over_matrix()
	local wh=is_highscore_achieved and 92 or 32
	draw_window(32,63-wh/2,64,wh,"game over",6,1,draw_game_over_content)
end

function draw_game_over_content(x,y)
	if is_highscore_achieved then
		draw_highscore_edit(x,y)
		print(chr(151).."confirm score",x,y+76)
	else
		print(chr(151).."start screen",x,y+16)
	end
end

-->8
--shared
--==============================
function draw_game_ui() 
	print("score:"..score,79,4,6)
	print("-------")
	print("level:"..level)
	print("lines:"..cleared_lines)
	--next mino
	if #bag.content>0 then
		draw_next_mino(bag.content[#bag.content],79,109)
	end
end

function draw_grid()
	local x=c_grid_x
 	local y=c_grid_y 
	color(6)
	--start tl->cv
	line(x-1,y-1,x+c_grid_w,y-1)
	line(x+c_grid_w,y+c_grid_h)
	line(x-1,y+c_grid_h)
	line(x-1,y-1)
end

--[[
x=window x position
y=window y position
w=window width
h=window height
t=window title
fgc=foreground color
bgc=background color
content=function for drawing the content of the window
cx=content x offset
cy=content y offset	
]]
function draw_window(x,y,w,h,t,fgc,bgc,content)
	rectfill(x,y,x+w,y+h,bgc)
	rect(x,y,x+w,y+h,fgc)
	print(t,x+2,y+2,fgc)
	line(x,y+8,x+w,y+8)
	content(x+2,y+10)
end

-->8
--highscore
--==============================
--mod4
-- -5,-4,-3,-2,-1,0,1,2,3,4,5
--  3, 4, 1, 2, 3,4,1,2,3,4,1,	
function wrap_value(v,min,max)
    range=max-min+1
	if v>0 then 
		v=v%range
        if v==0 then
            return max
        else
            return v+(min-1)
        end
	else
		v=abs(v)%range
		if v==0 then
			return max 
		else
			return max-v
		end
	end
end

function get_name()
	local out=""
	for char in all(current_editable_name) do
		out=out..char
	end
	return out
end

is_highscore_achieved=false 
-- 31 different chars possible (2ょ●6)
-- 0|32 for end of string
encode = {
	a=1,b=2,c=3,d=4,e=5,f=6,g=7,
	h=8,i=9,j=10,k=11,l=12,m=13,
	n=14,o=15,p=16,q=17,r=18,
	s=19,t=20,u=21,v=22,w=23,
	x=24,y=25,z=26
}
encode["<"]=27
encode["_"]=28
encode["-"]=29
encode["+"]=30
encode["|"]=31

decode = {
	"a","b","c","d","e","f","g","h",
	"i","j","k","l","m","n","o","p","q",
	"r","s","t","u","v","w","x","y","z",
	"<","_","-","+","|"
}

function save_highscore(name, score)		
	-- find index at which new score is added
	local score_index
	for i=1,#highscore do
		if(score > highscore[i].score) then
			score_index = i
			break
		end
	end

	if score_index ~= nil then
		add(highscore,{name=name,score=score},score_index)
		deli(highscore)
		write_highscore_to_cartrige()
	end
end

function read_highscore_from_cartrige()
	highscore={}
	for i=0,19,2 do
		local name = decodeName(dget(i)) -- decode to string
		local score = dget(i+1)
		add(highscore,{name=name,score=score})
	end
end

function write_highscore_to_cartrige()
	for i=1,#highscore do
		dset((i-1)*2,encodeName(highscore[i].name))
		dset(((i-1)*2)+1,highscore[i].score)
	end
end

--number to string
--64=...0100.0000 >>>5 -> x0000010=2
--encoded is a 32bit value
--64 -> 0x0040.0000 -> binary: 0000 0000 0010 0000 0000 0000 0000 0000
function decodeName(encoded)
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
		local char = decode[val]
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
function encodeName(name)
	name=split(name,"")
	local char_index=0
	local word_length=6
	local encoded=0.0
	local max_char_bits=5
	for char in all(name) do
		local num = encode[char]
		 --convert to 32bit integer by removing the fractional bits 
		num = num >>> 16
		--move the bits to the correct position in a 32bit array
		num = num << (char_index * max_char_bits) 
		encoded = encoded | num	
		char_index+=1
	end
	return encoded
end

function draw_highscore_read(x,y)
	color(7)
	local char_height=7
	for i=1,#highscore do
		local temp_y=y+(i-1)*char_height
		local token=". "
		if(i>=10) token="."
		if highscore[i].score==0 then 
			print(i..token,x,temp_y)
		else
			print(i..token..highscore[i].name,x,temp_y)
			print(highscore[i].score,x+38+get_x_offset(highscore[i].score),temp_y)
		end
	end	
end

function draw_highscore_edit(x,y)
	color(e_colors.white)
	local is_score_inserted=false

	local char_width=4
	local char_height=7
	local active_letter_x=x+(3*char_width)+(current_edit_index-1)*char_width
	
	for i=1,#highscore do
		local temp_y=y+(i-1)*char_height
		local token=". "
		if(i>=10) token="."
		if not is_score_inserted and score > highscore[i].score then
			rectfill(active_letter_x,temp_y,active_letter_x+char_width-2,temp_y+5,e_colors.red)
			color(e_colors.white)
			print(i..token,x,temp_y)
			print(get_name(),x+12,temp_y)
			print(score,x+38+get_x_offset(score),temp_y)
			is_score_inserted=true
		elseif highscore[i+(is_score_inserted and -1 or 0)].score==0 then 
			print(i..token,x,temp_y)
		else 
			print(i..token..highscore[i+(is_score_inserted and -1 or 0)].name,x,temp_y)
			local highscore = highscore[i+(is_score_inserted and -1 or 0)].score
			print(highscore,x+38+get_x_offset(highscore),temp_y)
		end
	end	
end

-- to right align numbers
function get_x_offset(highscore)
	if(highscore > 9999)return 0
	if(highscore > 999)return 4
	if(highscore > 99)return 8
	if(highscore > 9)return 12
	return 16
end

function erase_all_highscores()
	for i=0,19 do
		dset(i,0)
	end
	read_highscore_from_cartrige()
end

function is_highscore(score)
	return score > highscore[#highscore].score
end

__gfx__
00000000111111008888880099999900333333002222220011111100555555000000000000000000000000000000000000000000000000000000000000000000
000000001cccc100899998009aaaa9003bbbb3002888820012222100511115000000000000000000000000000000000000000000000000000000000000000000
000000001cccc100899998009aaaa9003bbbb3002888820012222100511115000000000000000000000000000000000000000000000000000000000000000000
000000001cccc100899998009aaaa9003bbbb3002888820012222100511115000000000000000000000000000000000000000000000000000000000000000000
000000001cccc100899998009aaaa9003bbbb3002888820012222100511115000000000000000000000000000000000000000000000000000000000000000000
00000000111111008888880099999900333333002222220011111100555555000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000001050090500b0500c0500d0501105014050160501805019050190501905019050170501605015050160501a05020050240502605027050290502a0502b0502c0502a0502505023050210501b0501f050
__music__
00 03424344

