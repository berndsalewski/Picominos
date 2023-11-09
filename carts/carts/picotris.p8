pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

-- global constants
-- highest integer value in pico
int_max=32767

GAME_STATES={none=0,start=1,game=2,game_over=3, game_over_screen=4}
game_state=GAME_STATES.none

function _init()
	game_state=GAME_STATES.start
end

function _update60()
	if game_state==GAME_STATES.game then
		game_running.update()
	elseif game_state==GAME_STATES.start then
		game_start.update()
	elseif game_state==GAME_STATES.game_over_screen then
		game_over_screen.update()
	end
end

--30fps or 15fps
--60fps with update60
function _draw()
	cls()
	rect(0,0,127,127,5)
	if game_state==GAME_STATES.start then
		game_start.draw()
	elseif game_state==GAME_STATES.game then
		game_running.draw()
	elseif game_state==GAME_STATES.game_over then
		game_over.draw()
	elseif game_state==GAME_STATES.game_over_screen then
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
		game_state=GAME_STATES.game
	end
end

function game_start.draw()
	rectfill(1,1,126,7,1)
	local w=print("picotris",2,2,6)
	line(1,9,126,9,5)
	line(1,8,126,8,6)
	print("❎".."start game",40,60,6)
	print("⬅️".."left|".."➡️".."right",2,109,5)
	print("⬇️".."fast drop",2,115)
	print("🅾️".."rotate left|".."❎".."rotate right",2,121)
end

-->8
--game_running
--==============================
--config
cells_hor=10
cells_vert=20
cs=6 --cellsize in pixel
grid_h=cells_vert*cs
grid_w=cells_hor*cs
grid_x=64-grid_w/2-18
grid_y=4

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

MINO_TYPES={none=0,i=1,l=2,o=3,s=4,z=5,t=6,j=7}
MINO_DIRECTIONS={n=1,e=2,s=3,w=4}

mino={
	pos=nil, -- 4 xy coordinates
	typ=MINO_TYPES.none,
	rot=MINO_DIRECTIONS.n
}
-- rotation matrices 
-- 1=n>e,2=e>s,3=s>w,4=w>n
MINO_ROTATIONS={
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
MINO_SPAWN_POS={
	{3,2,4,2,5,2,6,2},--i
	{3,2,4,2,5,2,3,3},--l
	{4,2,5,2,5,3,4,3},--o
	{4,2,5,2,3,3,4,3},--s
	{3,2,4,2,4,3,5,3},--z
	{3,2,4,2,5,2,4,3},--t
	{3,2,4,2,5,2,5,3}--j
}

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
MAX_LEVEL=19
LINE_SCORE_FACTOR={40,100,300,1200}
cleared_lines=0
level=0
score=0

-- soft dropping
softdrop_line_count=0
is_softdropping=false
is_btn_down_pressed=false
-- how many frames pass before 1 cell move -> 1/3G
softdrop_speed=3
-- drop speed per level defined as frame count between drops 
mino_drop_speed={53,49,45,41,37,33,28,22,17,11,10,9,8,7,6,6,5,5,4,4,3}
-- frames since game start, reset when value exceeds max_int
frame_count=0
-- the last frame when the mino was dropped
last_drop_frame=0

-- ARE entry delay see: https://tetris.wiki/ARE
frames_since_lock=0
ARE=2 

LINE_CLEAR_DELAY=93
frames_since_clear=0
-- was at least 1 line cleared with the last drop?
is_line_cleared=false
lines_to_clear={}

game_running={}
function game_running.update()
	if frame_count==int_max then
		frame_count=frame_count-last_drop_frame
		last_drop_frame=0
	end

	frame_count+=1
	
	if mino.pos==nil then
		if is_line_cleared then
			frames_since_clear+=1
			if frames_since_clear==LINE_CLEAR_DELAY then
				remove_cleared_lines()
				blink_animation_framecount=0
				spawn_mino()
				is_line_cleared=false
				frames_since_clear=0
			end
		elseif frames_since_lock==ARE then
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
		if frame_count-last_drop_frame >= softdrop_speed then
			move_mino({x=0,y=1})
			last_drop_frame=frame_count
		end
	-- auto drop
	elseif frame_count-last_drop_frame >= mino_drop_speed[level+1] then
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
			and (new_y>=cells_vert or not is_empty_cell(new_x,new_y)) then 
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

		for y=cells_vert,1,-1 do
			for x=1,cells_hor do
				if matrix[x][y] == 0 then
					break;
				end

				if x==cells_hor then
					--remove this row
					add(lines_to_clear,y)
				end
			end
		end
		if #lines_to_clear>0 then
			cleared_lines+=#lines_to_clear
			local new_level=cleared_lines\10 --integer division
			if(new_level~=level and new_level<=MAX_LEVEL)level=new_level
			score+=LINE_SCORE_FACTOR[#lines_to_clear]*(level+1)
			is_line_cleared=true
		end
		is_softdropping=false
		last_drop_frame=frame_count
		mino.pos=nil
	end
end

function spawn_mino()
	mino.rot=MINO_DIRECTIONS.n
	mino.pos={}
	mino.typ=bag:get_next()
	for v in all(MINO_SPAWN_POS[mino.typ])do
		add(mino.pos,v)
	end
	for i=1,7,2 do
		local x=mino.pos[i]
		local y=mino.pos[i+1]
		if matrix[x][y] ~= 0 then
			game_state=GAME_STATES.game_over
		end
	end 
end

function rotate_mino(dir)
	local rot_valid=true
	local new_mino={}
	if dir=="cv" then
		for i=1,#mino.pos do
			local new_pos=mino.pos[i]+MINO_ROTATIONS[mino.typ][mino.rot][i]
			if i%2==0 then -- y pos
				if new_pos<0 or new_pos>=cells_vert then
					rot_valid=false
					break
				end		
			else -- x pos
				if new_pos<0 or new_pos>=cells_hor then
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
			local new_pos=mino.pos[i]-MINO_ROTATIONS[mino.typ][next_cur_rot][i]
			if i%2==0 then
				if new_pos<0 or new_pos>=cells_vert then
					rot_valid=false
					break
				end		
			else
				if new_pos<0 or new_pos>=cells_hor then
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

blink_rate=20
blink_animation_framecount=0
function draw_matrix()
	if(#lines_to_clear>0)blink_animation_framecount+=1
	for x=1,cells_hor do
		for y=1,cells_vert do
			local draw=true
			if #lines_to_clear>0 then
				for i=1,#lines_to_clear do
					if lines_to_clear[i]==y and blink_animation_framecount%blink_rate>0 and blink_animation_framecount%blink_rate<11 then
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
	local x1=grid_x+x*cs
	local y1=grid_y+y*cs
	spr(spr_idx,x1,y1)
end

function draw_mino()
	if mino.pos==nil then return end	
	for i=1,7,2 do
		spr(mino.typ,
			grid_x+mino.pos[i]*cs,
			grid_y+mino.pos[i+1]*cs)
	end
end

function draw_next_mino(type,x,y)
	rect(x,y,x+27,y+15)	
	for i=1,7,2 do
		spr(type,
			-16+x+MINO_SPAWN_POS[type][i]*cs,
			-10+y+MINO_SPAWN_POS[type][i+1]*cs)
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
	for x=1,cells_hor do
		matrix[x]={}
		for y=1,cells_vert do
			matrix[x][y]=0
		end
	end
end

function remove_cleared_lines()
	for y in all(lines_to_clear) do
		for x=1,cells_hor do
			matrix[x][y]=0
		end
	end
	--gravity kicks in
	local i=0
	for v in all(lines_to_clear) do
		for y=v-1+i,1,-1 do
			for x=1,cells_hor do
				matrix[x][y+1]=matrix[x][y]
			end
		end
		i+=1
	end
	lines_to_clear={}
end

function is_on_grid(x,y)
	return x>=0 and x<cells_hor and y>=0 and y<cells_vert
end

function is_empty_cell(x,y)
	if(x==-1)x=0
	if(x==cells_hor)x=cells_hor-1
	if(y==-1)y=0
	if(y==cells_vert)y=cells_vert-1
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

pointer=0
finished=false
max_cells=cells_vert*cells_hor
cells={}
function draw_game_over_matrix()
	for i=0, pointer do
		local x=i%cells_hor 
		local y=(cells_vert-1)-i\cells_hor
		if(cells[i]==nil)cells[i]=rnd(7)+1 
		draw_cell(x,y,cells[i])
	end

	finished=pointer==max_cells-1
	
	if finished then 
		game_state=GAME_STATES.game_over_screen
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
function game_over_screen.update()
	if btnp(4) then 
		game_state=GAME_STATES.start
		reset_game_over_matrix()
	end
	if btnp(5) then 
		init_game_state()
		game_state=GAME_STATES.game
		reset_game_over_matrix()
	end
end

function game_over_screen.draw()
	draw_grid()
	draw_matrix()
	draw_game_ui()
	draw_game_over_matrix()
	rectfill(32,32,96,64,1)
	rect(32,32,96,64,6)
	print("game over",34,34,6)
	line(32,40,96,40)
	print(chr(151).."new game",34,52)
	print(chr(142).."start screen")
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
	local x=grid_x
 	local y=grid_y 
	color(6)
	--start tl->cv
	line(x-1,y-1,x+grid_w,y-1)
	line(x+grid_w,y+grid_h)
	line(x-1,y+grid_h)
	line(x-1,y-1)
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

