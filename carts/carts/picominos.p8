pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
#include common.lua
#include highscore.lua

cart_id="picominos"

e_game_states={none=0,start=1,match=2,game_over=3, highscore=4}
game_state=e_game_states.none

function _init()
	game_state=e_game_states.start
	cartdata(cart_id)
	hs:init()
end

function _update60()
	if game_state==e_game_states.start then
		game_state_start:update()
	elseif game_state==e_game_states.match then
		game_state_match:update()
	elseif game_state==e_game_states.highscore then
		game_state_highscore:update()	
	end
end

--30fps or 15fps
--60fps with update60
function _draw()
	cls()
	rect(0,0,127,127,5)
	if game_state==e_game_states.start then
		game_state_start:draw()
	elseif game_state==e_game_states.match then
		game_state_match:draw()
	elseif game_state==e_game_states.game_over then
		game_state_game_over:draw()
	elseif game_state==e_game_states.highscore then
		game_state_highscore:draw()
	end
end

function draw_game_ui() 
	print("score:"..score,79,4,6)
	print("-------")
	print("level:"..level)
	print("lines:"..cleared_lines)
	--next mino
	if #mino_bag.content>0 then
		draw_next_mino(mino_bag.content[#mino_bag.content],79,109)
	end
end

function draw_grid_border()
	local x=c_grid_x
 	local y=c_grid_y 
	color(6)
	--start topleft->clockwise
	line(x-1,y-1,x+c_grid_w,y-1)
	line(x+c_grid_w,y+c_grid_h)
	line(x-1,y+c_grid_h)
	line(x-1,y-1)
end

-->8
--game_start
--==============================
game_state_start={
	is_initialised=false,
	show_highscore=false,
	minos={},
	mino_coords={
		rectangle:new({x=64,y=0,w=4,h=1}),--i
		rectangle:new({x=64,y=1,w=3,h=2}),--l
		rectangle:new({x=67,y=3,w=2,h=2}),--o
		rectangle:new({x=64,y=5,w=3,h=2}),--s
		rectangle:new({x=64,y=3,w=3,h=2}),--z
		rectangle:new({x=68,y=0,w=3,h=2}),--t
		rectangle:new({x=67,y=1,w=3,h=2}),--j
	}
}

function game_state_start:init()
	game_state_start:spawn_minos()
	self.is_initialised=true
end

function game_state_start:update()
	if not self.is_initialised then
		self:init()
	end

	if btnp(5) then
		game_state=e_game_states.match
		self.is_initialised=false
	end

	if(btnp(4)) then
		self.show_highscore=not self.show_highscore
	end

	game_state_start:update_minos()
end

function game_state_start:draw()
	game_state_start:draw_background()

	if self.show_highscore then
		hs:draw_highscore(34,14)
		print("❎start game",40,90,6)
		print("🅾️title",40,96,6)

	else
		sspr(72,0,50,32,39,30)
		print("❎start game",40,90,6)
		print("🅾️highscore",40,96,6)
	end
	
	--print("❎start game 🅾️toggle highscore",20,100,6)
	print("⬅️left|➡️right",2,109,5)
	print("⬇️fast drop",2,115)
	print("🅾️rotate left|❎rotate right",2,121)
end

function game_state_start:draw_background()
	for i=1,#self.minos do
		--index 1,width 4,height 1
		local mino=self.mino_coords[self.minos[i].idx]
		sspr(mino.x,mino.y,mino.w,mino.h,self.minos[i].x,flr(self.minos[i].y))
	end
end

function game_state_start:spawn_minos()
	for x=10,120,10 do
		for y=10,120,10 do
			if(rnd(1)>0.6)then
				add(self.minos,{idx=flr(rnd(6))+1,["x"]=x,["y"]=y, v=rnd(0.2)+0.2})	
			end
		end 
	end
end

function game_state_start:update_minos()
	for _,v in ipairs(self.minos) do
		v.y+=v.v
		if v.y>126 then
			v.y=1
			v.x=flr((rnd(12.3)+0.1)*10)
			v.v=rnd(0.2)+0.2
		end
	end
end

-->8
--match
--==============================
game_state_match={is_initialised=false}

--config
c_cells_hor=10
c_cells_vert=20
c_cell_size=6
c_grid_h=c_cells_vert*c_cell_size
c_grid_w=c_cells_hor*c_cell_size
c_grid_x=64-c_grid_w/2-18
c_grid_y=4

-- match variables & constants
c_max_level=19
c_line_score_factor={40,100,300,1200}
cleared_lines=0
level=0
-- score is stored as a string to allow for higher values than 16bit integers
score="0"
max_score="999999"
-- soft dropping
softdrop_line_count=0
is_softdropping=false
is_btn_down_pressed=false
-- how many frames pass before 1 cell move -> 1/3G
c_softdrop_speed=3
-- drop speed per level defined as frame count between drops 
c_mino_drop_speeds={53,49,45,41,37,33,28,22,17,11,10,9,8,7,6,6,5,5,4,4,3}
-- frames since match start
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

c_line_clear_blink_rate=20
line_clear_blink_framecount=0

--[[
stores the e_mino_types for a 
coordinate on the board -> matrix[x][y]
1-indexed but coordinates are 0-indexed
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
mino_bag={
	content={}
}
function mino_bag:get_next()
	local next=deli(self.content,#self.content)
	if(#self.content==0)self:fill(self)
	return next
end
function mino_bag:fill()
	local types={1,2,3,4,5,6,7}
	self.content={}
	for i=1,#types do
		local n=rnd(types)
		del(types,n)
		add(self.content,n)
	end
end

function game_state_match:init()
	mino_bag:fill()
	lines=0
	level=0
	score="0"
	init_matrix()
	frame_count=0
	last_drop_frame=0
	self.is_initialised=true
end

function game_state_match:exit(state)
	game_state=state
	self.is_initialised=false
end

function game_state_match:update()
	if not self.is_initialised then
		self:init()
	end

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
				line_clear_blink_framecount=0
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

function game_state_match:draw()
	draw_grid_border()
	draw_matrix()
	draw_game_ui()
	draw_mino()
end

-- dir: {x,y}
function move_mino(dir)
	if(mino.pos==nil)return
	
	local locked=false
	local is_valid_move

	for i=1,7,2 do
		local new_x=mino.pos[i]+dir.x
	 	local new_y=mino.pos[i+1]+dir.y
	 	is_valid_move=is_on_grid(new_x,new_y) and is_empty_cell(new_x,new_y)
		if not is_valid_move 
			and dir.y==1	
			and (new_y>=c_cells_vert or not is_empty_cell(new_x,new_y)) then 
			locked=true 
		end
		if(not is_valid_move) break 
	end

	if is_valid_move then
		for j=1,7,2 do
			mino.pos[j]=mino.pos[j]+dir.x
			mino.pos[j+1]=mino.pos[j+1]+dir.y
		end
		if(is_softdropping)softdrop_line_count+=1
	end

	if locked then
		for i=1,7,2 do
			local x=mino.pos[i]+1
			local y=mino.pos[i+1]+1
			matrix[x][y]=mino.typ
		end

		add_to_score(softdrop_line_count)
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
			add_to_score(c_line_score_factor[#lines_to_clear]*(level+1))
			is_line_cleared=true
		end
		is_softdropping=false
		last_drop_frame=frame_count
		mino.pos=nil
	end
end

-- for storing values exceeding the 16 bit range of pico
-- we need to store the number as a string and use 
-- tonum() and tostr() with flag '0x2' to convert between
-- string and 32 bit number values
function add_to_score(val_16)
	local val_32=val_16>>>16
	local score_32=tonum(score,0x2)
	local result_32=score_32+val_32
	score=tostr(result_32,0x2)
end

function spawn_mino()
	mino.rot=e_mino_directions.n
	mino.pos={}
	mino.typ=mino_bag:get_next()
	for v in all(c_mino_spawn_positions[mino.typ])do
		add(mino.pos,v)
	end
	for i=1,7,2 do
		local x=mino.pos[i]
		local y=mino.pos[i+1]
		if matrix[x][y] ~= 0 then
			game_state_match:exit(e_game_states.game_over)
		end
	end 
end

function rotate_mino(dir)
	if(mino.pos==nil)return

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

function draw_matrix()
	if #matrix==0 then return end
	if(#lines_to_clear>0)line_clear_blink_framecount+=1
	for x=1,c_cells_hor do
		for y=1,c_cells_vert do
			local draw=true
			if #lines_to_clear>0 then
				for i=1,#lines_to_clear do
					if lines_to_clear[i]==y and line_clear_blink_framecount%c_line_clear_blink_rate>0 and line_clear_blink_framecount%c_line_clear_blink_rate<11 then
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
	if(mino.pos==nil)return

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

function init_matrix()
	for x=1,c_cells_hor do
		matrix[x]={}
		for y=1,c_cells_vert do
			matrix[x][y]=e_mino_types.none
		end
	end
end

function remove_cleared_lines()
	for y in all(lines_to_clear) do
		for x=1,c_cells_hor do
			matrix[x][y]=e_mino_types.none
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
	return matrix[x+1][y+1]==e_mino_types.none 
end

-->8
--game_over
--==============================
game_state_game_over={}
function game_state_game_over:draw()
	draw_grid_border()
	draw_matrix()
	draw_game_ui()
	draw_game_over_matrix()
end

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
		hs:send_score(score)
		game_state=e_game_states.highscore
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
--highscore state
--==============================
game_state_highscore={is_game_over_screen_initialised=false}

function game_state_highscore:init()
	hs:reset()
	self.is_game_over_screen_initialised=true
end

function game_state_highscore:update()
	if not self.is_game_over_screen_initialised then 
		self:init()
	end

	hs:update()
	hs.on_confirmed=function()
		reset_game_over_matrix()
		game_state=e_game_states.start
		self.is_game_over_screen_initialised=false
		self:exit()
	end
end

function game_state_highscore:draw()
	draw_grid_border()
	draw_matrix()
	draw_game_ui()
	draw_game_over_matrix()
	local wh=hs.is_highscore_achieved and 92 or 32
	draw_window(32,63-wh/2,64,wh,"game over",6,1,draw_game_over_content)
end

function game_state_highscore:exit()
	self.is_game_over_screen_initialised=false
end

function draw_game_over_content(x,y)
	if hs.is_highscore_achieved then
		hs:edit_highscore(x,y)
		print(chr(151).."confirm score",x,y+76)
	else
		print(chr(151).."start screen",x,y+16)
	end
end
__gfx__
0000000011111100888888009999990033333300222222001111110055555500cccc02220cc10000000c1000bb3000882000820000aaaaa400000eeee2000000
000000001cccc100899998009aaaa9003bbbb300288882001222210051111500999d00200ccc100000cc1000bb300088820082000aa4000a400ee2000e200000
000000001cccc100899998009aaaa9003bbbb300288882001222210051111500900ddd000cc1c1000c1c10000000008828208200aa400000a40ee20000000000
000000001cccc100899998009aaaa9003bbbb300288882001222210051111500bb0aa0000cc10c10c10c1000bb30008820828200aa400000a40ee20000000000
000000001cccc100899998009aaaa9003bbbb3002888820012222100511115000bbaa0000cc100cc100c1000bb30008820088200aa400000a4000eeee2000000
0000000011111100888888009999990033333300222222001111110055555500088000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000880000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40000000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb30008820008200aa400000a40ee2000e200000
0000000000000000000000000000000000000000000000000000000000000000000000000cc10000000c1000bb300088200082000aa4000a400ee200e2000000
000000000000000000000000000000000000000000000000000000000000000000000000cccc100000ccc10bbbb308888208882000aaaaa40000eeee20000000
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110000001050090500b0500c0500d0501105014050160501805019050190501905019050170501605015050160501a05020050240502605027050290502a0502b0502c0502a0502505023050210501b0501f050
__music__
00 03424344

