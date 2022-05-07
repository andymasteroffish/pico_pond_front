pico-8 cartridge // http://www.pico-8.com
version 35
__lua__

--networking
--https://www.lexaloffle.com/bbs/?tid=3909

--audio
--https://www.lexaloffle.com/dl/docs/pico-8_manual.html#Appendix_A

--frog pic
--https://opengameart.org/content/pixel-frog-0

--[[
when you export, it will overwite your HTML, so be ready to copy/paste that
--]]

my_val = 0
my_id = 0

can_press = true

outgoing_pin = 100
my_id_pin = 101

frogs = {}
num_frogs = 20

--TODO: sort frogs by Y so sprites are drawn on top of each other right
positions = {}
position_padding = 10
num_position_choices = 4    --generate this many and select the "best" for each frog

growth_rate = 1
decay_rate = 1
max_val = 100

function _init()
	printh("hello")

    --setting my id for testing
    --this should start at -1 or something and wait to be set by the javascript
    poke(0x5f80+my_id_pin, 99);  

    --setting these values persists between runs
    print(peek(0x5f80+2))   --print value of slot 2
    poke(0x5f80, 5);        --set the value of slot 0 to 5
    poke(0x5f80+2, 6);      --set the value of slot 2 to 6
    print(peek(0x5f80+2))

    print(peek(0x5f80+99))
    poke(0x5f80+99, 7);

    --start all frog pins at 200
    for i=1,num_frogs do
        poke(0x5f80+i, 200); 
    end

    generate_placement()

    --init frogs
    for i=1,num_frogs do
        frogs[i] = {
            x = 0,
            y = 0,
            remote_val = 0,
            val = 0,
            is_active = false,
            is_local = false
        }
    end

end

function _update()
    --print(peek(0x5f80+2))

    --check the button
    if btn(5) and can_press then
        my_val += growth_rate
        poke(0x5f80+outgoing_pin, 1);
    else
        my_val -= decay_rate
        can_press = false
        poke(0x5f80+outgoing_pin, 0);
    end

    if my_val < 0 then
        my_val = 0
        can_press = true
    end
    if my_val > max_val then
        my_val = max_val
    end

    --set the local frog (this really only needs to happen once)
    my_id = peek(0x5f80+my_id_pin)
    if my_id > 0 and my_id <= num_frogs then
        frogs[my_id].is_local = true
    end

    --grab the values from the pins
    for i=1,num_frogs do
        local val = peek(0x5f80+i)
        frogs[i].remote_val = val
    end



    --update frogs
    for frog in all (frogs) do

        
        
        --is it time to drop the value?
        if frog.remote_val == 0 then
            frog.val -= decay_rate
            if frog.val < 0 then frog.val = 0 end
        elseif frog.is_active then
            frog.val = frog.remote_val  --you could lerp this to make it look nicer
        else
            frog.val = 0
        end

        --if this is the local frog, set the values
        if frog.is_local then
            frog.remote_val = my_val
            frog.val = my_val
        end

        --if the val is in range, then this frog is active
        frog.is_active = frog.remote_val <= max_val

        

        

    end


    

    --store it!
    --poke(0x5f80+0, my_val);
    
end



function _draw()
    cls(0)

    --spr(1, 50,50, 4,3 )
    --local sprite_scale = 1-- 1.5 + sin(t()/4)

    -- pal()
    -- sspr(8,0, 32,24, 50,30, 32*sprite_scale, 24*sprite_scale)

    -- pal({[3]=15,[12]=2})
    -- sspr(8,0, 32,24, 50,60, 32*sprite_scale, 24*sprite_scale)

    srand(1)
    for i=1,num_frogs do
        
        local sprite_scale = 1-- + rnd(1)
        local flip = rnd() > 0.5
        base_w = 24
        base_h = 19
        spr_w = base_w*sprite_scale
        spr_h = base_h*sprite_scale
        sspr(40,0, base_w,base_h, positions[i].x-spr_w/2,positions[i].y-spr_h/2, spr_w, spr_h, flip, false)
    end

    debug_draw()

    
end

function debug_draw()
    left_x = 2
    mid_dist = 30
    left_x2 = left_x + mid_dist + 20
    --mid_x2 = left_x2+30
    text_h = 6
    cur_col = 1
    
    print(my_val, left_x, cur_col * text_h, 7)
    cur_col += 1
    print("- - -", left_x, cur_col * text_h)
    cur_col += 1
    for i=1,num_frogs do 
        x_pos = left_x
        if(i>10)    x_pos = left_x2
        local frog = frogs[i]
        color = 7
        if (frog.is_active == false)    color = 5
        raw_text = i..":"..frog.remote_val
        if frog.is_local then
            raw_text = "♥:"..my_val
        end
        print(raw_text, x_pos, text_h * cur_col, color)
        print(frog.val, x_pos+mid_dist, text_h * cur_col )
        cur_col += 1
        if (i==10)  cur_col = 3
    end
    print("- - -", left_x, cur_col * text_h, 7)
    cur_col += 1
    for i=100,105 do
        print(i..":"..peek(0x5f80+i), left_x, cur_col * text_h)
        cur_col += 1
    end
end

function play_sound()
    --(x) effect 1, 3 sounds pretty froggy
        --5 is a little froggy
    --(v) volume maxes out at 7
    --(i) instruments: 0,1,2,3, 5,7
    --(s) speed  can go up to 9. higher = slower
    if btnp(4) then
        --?"\ace-g"
        ?"\as9v7x3i0f..d-..f"
        --?"\as4x5c1eg2egc3egc4"
        --?"\ab"
    end
end

--
-- Generate Placement
-- Creates a list of placements somewhat spaced out from eahc other
--
function generate_placement()
    srand(10)   --selected this number because it looked nice

    placements = {}

    for i=1,num_frogs do

        --generate choices
        local choices = {}
        for j=1,num_position_choices do
            choices[j] = {
                x = position_padding + rnd(128-position_padding*2),
                y = position_padding + rnd(128-position_padding*2),
                min_dist = 999
            }
        end

        --compare to current placements
        for k=1,i-1 do
            printh(i.." against "..k)
            for j=1,num_position_choices do
                local dist = max(abs(choices[j].x-positions[k].x), abs(choices[j].y-positions[k].y))
                if choices[j].min_dist > dist then
                    choices[j].min_dist = dist
                    printh("    set to "..choices[j].min_dist)
                end
            end
        end

        local best_choice = choices[1]
        --printh("starting best: "..best_choice.min_dist)
        for j=2,num_position_choices do
            if best_choice.min_dist < choices[j].min_dist then
                best_choice = choices[j]
            end
        end

        positions[i] = best_choice
    end
end

__gfx__
00000000000000000000000000000000000000000000000000770000077000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000007707000770700000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000077000007700000000000000000007077000777000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000770700077070000000000000000007077333377000000000000000000000000000000000000000000000000000000000000000000000
0007700000000000000070770007770000000000000000000777c3333c7700000000000000000000000000000000000000000000000000000000000000000000
0070070000000000000070773333770000000000000000003ccc333333cc00000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000777c3333c770000000000000000333333333333300000000000000000000000000000000000000000000000000000000000000000000
00000000000000000003ccc333333cc00000000000000033333cccccccc300000000000000000000000000000000000000000000000000000000000000000000
0000000000000000003333333333333300000000003300333cccccccccc000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000333333333333330000000003333033ccccccccccc033300000000000000000000000000000000000000000000000000000000000000000
0000000000000000033333cccccccc3300000000333333cccccccccccc0333330000000000000000000000000000000000000000000000000000000000000000
00000000000033300333ccccccccccc0000000003333333cccccccccc33333330000000000000000000000000000000000000000000000000000000000000000
0000000000033333033ccccccccccc03333000003333cccccccccccc3cccc3330000000000000000000000000000000000000000000000000000000000000000
00000000003333333cccccccccccc033333300003333ccc3ccccccc3cccccc300000000000000000000000000000000000000000000000000000000000000000
000000000033333333cccccccccc3333333300000cc3cccc33cccc3ccccccc000000000000000000000000000000000000000000000000000000000000000000
00000000003333ccccccccccccc3ccccc333000000ccccccc33cc33cccccc0000000000000000000000000000000000000000000000000000000000000000000
00000000003333cccc3ccccccc3ccccccc300000000ccc000033c330ccccc0000000000000000000000000000000000000000000000000000000000000000000
00000000000cc3ccccc33cccc3cccccccc000000000ccc000033c330000ccc000000000000000000000000000000000000000000000000000000000000000000
000000000000cccccccc333c33ccccccc000000000c0c0c00c0ccc0c00c0c0c00000000000000000000000000000000000000000000000000000000000000000
0000000000000ccc0000033c330cccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ccccc0000033c330000cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000c0c000c0ccc0c00cc0c0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000c00c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
