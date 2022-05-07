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

growth_rate = 1.2
decay_rate = 3
max_val = 100

--debug stuff
show_debug = true

function _init()
	printh("hello")

    --setting my id for testing
    --this should start at 99 or something and wait to be set by the javascript
    poke(0x5f80+my_id_pin, 19);  

    --setting these values persists between runs
    -- print(peek(0x5f80+2))   --print value of slot 2
    -- poke(0x5f80, 5);        --set the value of slot 0 to 5
    -- poke(0x5f80+2, 6);      --set the value of slot 2 to 6
    -- print(peek(0x5f80+2))

    -- print(peek(0x5f80+99))
    -- poke(0x5f80+99, 7);

    --start all frog pins at 200 to mark them as not used
    for i=1,num_frogs do
        poke(0x5f80+i, 200); 
    end

    --define some selecitons
    instruments = {0, 1, 2, 3, 5, 7}
    notes = {'a', 'b', 'c', 'd', 'e', 'f', 'g'}

    --init frogs
    srand(0)
    for i=1,num_frogs do
        frogs[i] = {
            --x = positions[i].x,
            --y = positions[i].y,
            remote_val = 0,
            val = 0,
            is_active = false,
            is_local = false,
            col_a = 8+rnd(5),
            col_b = 8+rnd(5),
            flip = rnd() > 0.5,
            can_ribbit = false,
            instrument = instruments[i%6 +1]
        }

        --audio stuff
        --effect (I like effect 3 a bit better)
        if rnd() < 0.25 then
            frogs[i].effect = 1
        else
            frogs[i].effect = 3
        end

        printh(#notes)
        local high_note_id = flr(3 + rnd()*4)
        frogs[i].high_note = notes[high_note_id]
        frogs[i].low_note = notes[high_note_id-2]
        printh('high: '..frogs[i].high_note.."  low: "..frogs[i].low_note)
    end

    --generate the positions of the frogs
    generate_placement()

    -- --init frogs
    -- srand(0)
    -- for i=1,num_frogs do
    --     frogs[i] = {
    --         x = positions[i].x,
    --         y = positions[i].y,
    --         remote_val = 0,
    --         val = 0,
    --         is_active = false,
    --         is_local = false,
    --         col_a = 8+rnd(5),
    --         col_b = 8+rnd(5),
    --         flip = rnd() > 0.5
    --     }
    -- end

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
            
            if frog.val > 0 and frog.can_ribbit then
                frog.can_ribbit = false
                play_sound(frog)
            end

            --reduce the value
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

            --did they just lift up?
            if peek(0x5f80+outgoing_pin) == 0 and frog.val > 1 and frog.can_ribbit then
                frog.can_ribbit = false
                play_sound(frog)
            end
        end

         --only let frogs ribbit again once they've gone to 0
         if frog.val < 1 then
             frog.can_ribbit = true
         end

        --if the val is in range, then this frog is active
        frog.is_active = frog.remote_val <= max_val

        

        

    end


    --debug
    if (btnp(2)) show_debug = not show_debug
    if (btnp(0)) frogs[my_id].is_local=false, poke(0x5f80+my_id_pin, my_id-1)
    if (btnp(1)) frogs[my_id].is_local=false, poke(0x5f80+my_id_pin, my_id+1)
    
end



function _draw()
    cls(0)

    --spr(1, 50,50, 4,3 )
    --local sprite_scale = 1-- 1.5 + sin(t()/4)

    -- pal()
    -- sspr(8,0, 32,24, 50,30, 32*sprite_scale, 24*sprite_scale)

    -- pal({[3]=15,[12]=2})
    -- sspr(8,0, 32,24, 50,60, 32*sprite_scale, 24*sprite_scale)

    --render frogs
    for i=1,num_frogs do
        local frog = frogs[i]
        pal({[1]=frog.col_a,[2]=frog.col_b, [3]=0})
        local sprite_scale = 1 + (frog.val / 100)
        
        base_w = 24
        base_h = 19
        spr_w = base_w*sprite_scale
        spr_h = base_h*sprite_scale
        sspr(40,0, base_w,base_h, frog.x-spr_w/2,frog.y-spr_h + base_h/2, spr_w, spr_h, frog.flip, false)
    end

    if(show_debug)  debug_draw()

    
end

function debug_draw()
    left_x = 2
    mid_dist = 28
    left_x2 = left_x + mid_dist + 32
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
            raw_text = "♥:"..flr(my_val)
        end
        print(raw_text, x_pos, text_h * cur_col, color)
        print(flr(frog.val), x_pos+mid_dist, text_h * cur_col )

        print(frog.can_ribbit, x_pos+mid_dist + 10, text_h * cur_col )
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

function play_sound(frog)
    printh("play sound.  effect:"..frog.effect.. "  instrument:"..frog.instrument.."  high: "..frog.high_note.."  low: "..frog.low_note)
    local prc = frog.val / 100

    --(x) effect 1, 3 sounds pretty froggy
        --5 is a little froggy
    --(v) volume maxes out at 7
    --(i) instruments: 0,1,2,3, 5,7
    --(s) speed  can go up to 9. higher = slower
        --?"\ace-g"
        --?"\as9v7x3i0f..d-..f"
        --?"\as4x5c1eg2egc3egc4"
        --?"\ab"

    --start audio string
    local txt = "\a"
    --speed (max 9)
    local speed = 1 + prc * 8
    txt = txt .. "s"..flr(speed)
    --volume (max 7)
    local vol = 4+prc*3
    txt = txt .. "v"..flr(vol)
    --instrument
    txt = txt .. "i"..frog.instrument
    --effect
    txt = txt .. "x"..frog.effect
    --notes
    txt = txt .. frog.high_note .. ".." .. frog.low_note .. ".." .. frog.high_note .. ".." .. frog.low_note
    --txt = txt .. "f..d..f..d"

    --play the sound (via the print command lol)
    ?txt
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
            for j=1,num_position_choices do
                local dist = max(abs(choices[j].x-positions[k].x), abs(choices[j].y-positions[k].y))
                if choices[j].min_dist > dist then
                    choices[j].min_dist = dist
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

    --now have the frogs sort themselves top to bottom
    for i=1,num_frogs do
        local best_id = 1
        for k=1,num_frogs do
            if (positions[k].y < positions[best_id].y ) best_id = k
        end
        frogs[i].x = positions[best_id].x
        frogs[i].y = positions[best_id].y
        positions[best_id].y = 300    --take it out of the running
    end
end

__gfx__
00000000000000000000000000000000000000000000000000770000077000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000007737000773700000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000077000007700000000000000000007377000777300000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000770700077070000000000000000007377111177300000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000707700077700000000000000000007772111127700000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000707733337700000000000000000012221111112200000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000777c3333c770000000000000000111111111111100000000000000000000000000000000000000000000000000000000000000000000
00000000000000000003ccc333333cc0000000000000001111122222222100000000000000000000000000000000000000000000000000000000000000000000
00000000000000000033333333333333000000000011001112222222222000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000033333333333333000000000111101122222222222011100000000000000000000000000000000000000000000000000000000000000000
0000000000000000033333cccccccc33000000001111112222222222220111110000000000000000000000000000000000000000000000000000000000000000
00000000000033300333ccccccccccc0000000001111111222222222211111110000000000000000000000000000000000000000000000000000000000000000
0000000000033333033ccccccccccc03333000001111222222222222122221110000000000000000000000000000000000000000000000000000000000000000
00000000003333333cccccccccccc033333300001111222122222221222222100000000000000000000000000000000000000000000000000000000000000000
000000000033333333cccccccccc3333333300000221222211222212222222000000000000000000000000000000000000000000000000000000000000000000
00000000003333ccccccccccccc3ccccc33300000022222221122112222220000000000000000000000000000000000000000000000000000000000000000000
00000000003333cccc3ccccccc3ccccccc3000000002220000112110222220000000000000000000000000000000000000000000000000000000000000000000
00000000000cc3ccccc33cccc3cccccccc0000000002220000112110000222000000000000000000000000000000000000000000000000000000000000000000
000000000000cccccccc333c33ccccccc00000000020202002022202002020200000000000000000000000000000000000000000000000000000000000000000
0000000000000ccc0000033c330cccccc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000ccccc0000033c330000cccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000c0c000c0ccc0c00cc0c0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000c00c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
