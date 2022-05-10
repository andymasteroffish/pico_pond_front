pico-8 cartridge // http://www.pico-8.com
version 35
__lua__

--Demake by Andy Wallace
--andymakes.com
--@andy_makes

--Frog Chorus by v buckenham & Viviane Schwarz
--https://frogchorus.com/?pond=the_big_pond

--super helpful networking info by seleb
--https://www.lexaloffle.com/bbs/?tid=3909

--audio generation documentation
--https://www.lexaloffle.com/dl/docs/pico-8_manual.html#Appendix_A

--frog pic by scofanogd
--https://opengameart.org/content/pixel-frog-0


--player input values
my_val = 0
my_id = 0
can_press = true

--keeping track of our lovely frogs
frogs = {}
num_frogs = 20

--generating positions
positions = {}
position_padding = 10
num_position_choices = 4    --generate this many and select the "best" for each frog

--having the values rise and fall
growth_rate = 1.2
decay_rate = 3
max_val = 100

--pin numbers for communicating with JS
outgoing_pin = 100
my_id_pin = 101
cart_start_pin = 102    --to tell the js app we've started
status_pin = 103

--debug stuff
show_debug = false

--
-- Setup
--
function _init()

    --setting my id for testing
    --this should start at 99 or something and wait to be set by the javascript
    poke(0x5f80+my_id_pin, 99);  

    --start the status as "connecting"
    poke(0x5f80+status_pin, 1)

    --start all frog pins at 200 to mark them as not used
    for i=1,num_frogs do
        poke(0x5f80+i, 200); 
    end

    --make the background and store it in sprite sheet
    create_background()

    --make sure all instances get the same frogs by seeding random
    srand(1)

    --define some selections to use when making frogs
    instruments = {0, 1, 2, 3, 5, 7}
    notes = {'a', 'b', 'c', 'd', 'e', 'f', 'g'}

    main_colors = {12, 11,  8, 10}
    dark_colors = {4,  3,   2, 9}
    
    --init frogs
    for i=1,num_frogs do
        local col_id = 1 + flr(rnd(#main_colors))
        frogs[i] = {
            remote_val = 0,
            val = 0,
            is_active = false,
            is_local = false,
            col_a = main_colors[col_id],
            col_b = dark_colors[col_id],
            flip = rnd() > 0.5,
            can_ribbit = false,
            instrument = instruments[i%6 +1]
        }

        --audio stuff
        --random effect (I like effect 3 a bit better)
        if rnd() < 0.25 then
            frogs[i].effect = 1
        else
            frogs[i].effect = 3
        end

        --generate 2 notes for the frog to use
        local high_note_id = flr(3 + rnd()*4)
        frogs[i].high_note = notes[high_note_id]
        frogs[i].low_note = notes[high_note_id-2]
    end

    --generate the positions of the frogs
    generate_placement()

    --let the JS know we started
    poke(0x5f80+cart_start_pin, 1);  

end

--
-- Update
--
function _update()

    --check the button
    local holding = btn(5) or btn(4)
    if holding and can_press then
        my_val += growth_rate
        poke(0x5f80+outgoing_pin, 1);
    else
        my_val -= decay_rate
        can_press = false
        poke(0x5f80+outgoing_pin, 0);
    end

    --keep the value in range
    if my_val < 0 then
        my_val = 0
        can_press = true    --only let them press again once the button hits 0
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
            --play the sound if te value just started dropping
            if frog.val > 0 and frog.is_local == false and frog.can_ribbit then
                frog.can_ribbit = false
                play_sound(frog)
            end
            --reduce the value
            frog.val -= decay_rate
            if frog.val < 0 then frog.val = 0 end
        --if it is positive, grab the remote value
        elseif frog.is_active then
            frog.val = frog.remote_val 
        --if the frog is inactive keep it at 0
        else
            frog.val = 0
        end

        --if this is the local frog, set the values
        if frog.is_local then
            frog.remote_val = my_val
            frog.val = my_val

            --if they just lifted up on the button, play the sound
            if peek(0x5f80+outgoing_pin) == 0 and frog.val > 1 and frog.can_ribbit then
                frog.can_ribbit = false
                play_sound(frog)
            end
        end

         --only let frogs ribbit again once they've gone back to 0
         if frog.val < 1 then
             frog.can_ribbit = true
         end

        --if the val is in range, then this frog is active
        frog.is_active = frog.remote_val <= max_val
    end


    --debug stuff. uncomment if needed. Left and right will crash the game if you go out of range
    -- if (btnp(2)) show_debug = not show_debug
    -- if (btnp(0)) frogs[my_id].is_local=false, poke(0x5f80+my_id_pin, my_id-1)
    -- if (btnp(1)) frogs[my_id].is_local=false, poke(0x5f80+my_id_pin, my_id+1)
    
end


--
-- Draw
--
function _draw()
    cls(0)

    --background
    pal({[1]=0,[2]=1,[3]=5,[4]=1})
    sspr(24,19, 128-24,128-19, 0,0, 128, 128)

    --render frogs
    for i=1,num_frogs do
        local frog = frogs[i]
        if frog.is_active then
            pal({[1]=frog.col_a,[2]=frog.col_b, [3]=0})
            local sprite_scale = 1 + (frog.val / 100)
            
            base_w = 24
            base_h = 19
            spr_w = base_w*sprite_scale
            spr_h = base_h*sprite_scale
            sspr(0,0, base_w,base_h, frog.x-spr_w/2,frog.y-spr_h + base_h/2, spr_w, spr_h, frog.flip, false)
        end
    end

    --if we have anything to print, do that
    draw_status()

    if(show_debug)  debug_draw()
end

--
-- Status text
--
function draw_status()
    local status = peek(0x5f80+status_pin)
    --1: connecting
    if status==1 then
        outline_text("connecting to the pond...",20)
    end
    --2: connected (don't do anything)
    --3: full
    if status==3 then
        outline_text("the pond is full",20)
        outline_text("try again later",30)
    end
    --4: connection error
    if status==4 then
        outline_text("lost connection",20)
        outline_text("or couldn't connect",30)
        outline_text("to the pond :(",40)
        outline_text("refresh the page",60)
        outline_text("or try again later",70)
    end
end

--
-- Draws centered white text with blakc outline
--
function outline_text(text, y)
    --center x
    x = 64 - (#text) * 2
    --outline
    for c=-1,1 do
        for r=-1,1 do
            print(text,c+x,r+y,0)
        end
    end
    --white text
    print(text,x,y,7)
end

--
--used to get the cover picture for Itch
--
function draw_title()
    local frog = frogs[3]
    outline_text("pico pond", 50)
    pal({[1]=frog.col_a,[2]=frog.col_b, [3]=0})
    local sprite_scale = 1 + (frog.val / 100)
    base_w = 24
    base_h = 19
    sspr(0,0, base_w,base_h, 64-base_w/2,60, base_w, base_h, false, false)
end

--
--makes a pattern for the background and writes it to the sprite sheet
--
function create_background()
    cls()

    printh("make background")
    for y=-10,138,0.2 do
        s = 5 + rnd(10)
        padding = -10

        c = 1+flr(rnd(4))
        x = padding + rnd(128-padding*2)
        y = y
        circfill(x,y,s, c)
    end

    rectfill(0,0,24,19,0)
    
    --keep the frog there
    sspr(0,0, 24,19, 0,0)
    
    local sprite_start = 24576
    memcpy(0,sprite_start,8191)
end

--
-- Prints useful info to the screen
--
function debug_draw()
    left_x = 2
    mid_dist = 28
    left_x2 = left_x + mid_dist + 32
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

--
-- Plays a sound
-- uses the very hacky feeling control chars
-- https://www.lexaloffle.com/dl/docs/pico-8_manual.html#Appendix_A
--
function play_sound(frog)
    printh("play sound.  effect:"..frog.effect.. "  instrument:"..frog.instrument.."  high: "..frog.high_note.."  low: "..frog.low_note)
    local prc = frog.val / 100

    --(x) effect 1, 3 sounds pretty froggy
        --5 is a little froggy
    --(v) volume maxes out at 7
    --(i) instruments: 0,1,2,3, 5,7
    --(s) speed  can go up to 9. higher = slower

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
    --super inefficient sort. don't @ me.
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
00000000007700000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077370007737000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000073770007773000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000073771111773000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077721111277000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000122211111122000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000001111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000011111222222221000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00110011122222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01111011222222222220111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111122222222222201111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11111112222222222111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11112222222222221222211100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11112221222222212222221000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
02212222112222122222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00222222211221122222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00022200001121102222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00022200001121100002220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00202020020222020020202000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
01111155555555555555551111111100001110000000000000000000000111111111111111111111111111555555555511111111100000000000000000000000
11111111155555555555555111111110011100000000000000000000000111111111111111111111111115555555111111111111111100000000000000000000
11111111111555555555555551111111110000000000000000000000000011111111111111111111111155555551111111111111111111000000000000000000
11111111111555555555555551111111110000000000000000000000000011111111111111111111111155555551111111111111111111000000000000000000
11111111111111555555555551111111100000000000005555555500000000111111111111111111115555555511111155555555511111100000000000000000
11111111111111111555555551111111000000000005555555555555500555555111111111111111155555555555555555555555555111111111110000000000
11111111111111111155555555111111000000000055555555555555555555555555111111111111555555555555555555555555555555111111111110000011
11111111111111111111555555511111000000000555555500000000055555555555551111111115555555555555555555555555555555511111111000001111
11111111111111111111155555551111111111155555000000000000000055555555555111111115555555555555555555555555555555551111110000011110
11111111111111111111115555511111111111111110000000000000000000555555555111111155555555500000555555555555555555555111110000110000
11111111111111111111115555511111111111111110000000000000000000555555555111111155555555500000555555555555555555555111110000110000
11111111111100000011111555111111111111111000000000000000000000005555555551155555555555555550000555555555555555555111100005555555
11111111110011111111111111111111111111111100000000000000000011111111155551555555555555555555000111111115555111111511105555555555
55111111111111111111111111111111111111111110000000000000001111111111111555555555555555555555555111111111111111111111555555555555
55555511111111111111111111111111111111111111000000000000011111111111115555555555555555555555555511111111111111111155551111111115
55555511111111111111111111111111111111111111110000000011111111111111155111111111555555555111111111111111111111111511111111111111
55551111111111111111111111111111111111111111110000000011111111111111111111111111111155111111111111111111111111000111111111111111
55551111111111111111111111111111111111111111110000000011111111111111111111111111111155111111111111111111111111000111111111111111
55111111111111111111111111111111111111111111111000000111111111111111111111111111111111111111111111111111111000011111111111111111
51111111111111000000000000000000000000000000000000000011100000000000000000000000005550000000000000000111110000111111111111111111
51111111111110077007707700770077700770777077707700077011107770077000007770707077705550777007707700770011100011111111111111111111
11111111111110700070707070707070007000070007007070700011100700707000000700707070005550707070707070707010000011111111111111155555
11111111111110701070707070707077007011070107007070700011110700707000000700777077055550777070707070707000000111111111111111115555
10000000001110700070707070707070007000070007007070707000000700707000000700707070005550700070707070707000000001000111111111111115
10000000001110077077007070707077700770070077707070777000000700770000000700707077705550705077007070777007000701070111111111111115
00000000000011000000000000000000000000000000000000000000000000000000000000000000005550005000000000000000050001000111111111111111
00000000000111111111111111111111111111111111111000000000000000000000000001111111100055055555555555555555555555511111111111111111
00000000011111111111111111111111111111111111110000000000000000000011101111111111111100555555555555555555555555555111111111111111
11000001111111111111111111111111111111111111111111111111111100000000111111111111111115555555555555555555555555555511111111111111
11110111111111111111111111111111111111111111111111111111111111100000111111111111111111555555555555555555555555555555555111111111
11110111111111111111111111111111111111111111111111111111111111100000111111111111111111555555555555555555555555555555555111111111
15555555551111111111111111555551111111111111111111111111111111110011111115555555511111155555555555555555555555555555555555111111
55555555555555111111111111155555511111111111111111111111111111111111155555555555555551111555555555555555555555555555555555511111
55555555555555511111111110000005551111111111111111111111111111111111555555555555511111111155555555555555555555555555555551111111
55555555555555555111111000000000551111111111111111111111111111111111155555555511111111111111115555555555555555555555555111111111
51111111115555555511110000000000011111111111111111111111111111111111111555551111111111111111111511111111155555555555511111111111
10000000001155555555100000000000011111111111555111111111111111111111111115111111111111111111111111111111111155000000001111111111
10000000001155555555100000000000011111111111555111111111111111111111111115111111111111111111111111111111111155000000001111111111
00000000000000055555100000555555551111111155551111111111111111111111111111111111110000000001111111111111111111000000000001111111
11111100000000000555500555555555551111111115551111111111111111111111111111111110000000000000000111111155555555500000000000100000
11111111110000000000555555555555111111111111111111111111111111111111111111111100000000000000000011115555555555555000000000000000
11111111111100000000055555555511111111111111111111111111111111111111111111110000000000000000000005555555555555555555000000011111
11111111111111110000011111111111111111111111111111111111111111111111111111100000000000000000000555555555555555555555000111111111
11111111111111111011111111111111111111111111111111111111111111111111111111000000000000000000005555555555555111111111001111111111
11111111111111111011111111111111111111111111111111111111111111111111111111000000000000000000005555555555555111111111001111111111
11111111111111111111111111111111111111111111111111111111111111111111111110000000000000000000555555555551111111111111111000000000
00001111111111111111111111111111111111111111111111111111111111111111111000000000000000000005555555555511111111111111000000000000
00000001111111111111111111111111111111111111111111111111111111111111111000000000000000000055555555555111111111111100000000000011
00000000011111111555555111111111111111111111111111110000001555555555155555555511110000000555555555551111111111111000000000111111
00000000000111155555111111000000001111111555555110000005555555555555555555555555111110055555555555111111110000000000000001111111
00000000000011555111110000000000000000555555555550000055555555555555555555555555511111155555555551111110000000000000001111111111
00000000000011555111110000000000000000555555555550000055555555555555555555555555511111155555555551111110000000000000001111111111
11111100000000551111555555550000000000055555555555555555555555555555555555555555555511111555555511111000000000000000011111111111
11111111101111115555555555555555000000000055555555555555555555555555555555555555555511111555555511110005555555000000111111111111
11111111111111155555555555555555500000000005555555555555555555555555555555555555555551111111111511110555555555550000111111111111
11111111111155555555555555555555555500000000555555555555555555111111110000055555551111111111111111555555555555555555551111111111
11111111111511111111155555555555555550000000005555555555555111111111111110000055511111111111111111115555555555555555555555111115
11111111111511111111155555555555555550000000005555555555555111111111111110000055511111111111111111115555555555555555555555111115
11111111111111111111111555555555555555000000005555555555551111111111111111000005111155555555111111111555555555555555555555515555
11111111111111111111111111555555555555555000000555555555511111111111111111100001555555555555555511111155555555555555555555555555
11111111111111111111111111155555555555555555000055555551111111111111111111110015555555555555555551111155555555555555555555555555
11111111111111111111111111155555555555555555550055555511111111111111111111111155555555555555555555111555555555555555555555555555
11111111111111111111111111111111155555555555555555555511111111111111111111115555555555111111111555555555555555555555555555555555
11111111111111111155511111111111111155555555555555555111111111111111111111155555555511555555555115555555555555555555555555555500
11111111111111111155511111111111111155555555555555555111111111111111111111155555555511555555555115555555555555555555555555555500
11111111111111111111555111111111111115555555555555555111111111111111111111115555000000000555555551555555555555555555555555555555
11111111111111111111151111111111111111155555555555551111111111111111111111111100000000000005555555115555555555555555555555555555
11111111111555555555111111111111111111111555555555551111111111111111111111111111100000000000555555111111111555555555555555555555
11111115555555555555550000000001111100000000555555555511111111111111111111111111110000000000000511111111111155555555555555500000
11111155555555555500000000000000000000000055555555555555551111111111111111111111111100000000000111111111111555555555555550000001
11111555555555555000000000000000000000000555555555555555555111111111000000005555551110055555551000000001111555555555555000000010
11111555555555555000000000000000000000000555555555555555555111111111000000005555551110055555551000000001111555555555555000000010
11115555555555500000000000000000000000555555555555555555555555111000000000555555555551555555000000000000005555555555500000001100
51555555555555000000000000005551111111155555555555555511111111110000005555555555555555155500000000000000000055555555500000010000
55555555555500000000000000551111111111111155555555111111111111111100055555555550000000011000000000000000001111111155000000110000
55555555555500000000000005111111111111111111555551111111111111111111555555550000000000000000000000000001111111111111100001100000
55555555555000000000005551111111111111111111115111111111111111111111155555000000000000000000000000000011111111111111110111000000
55555555555000000000005551111111111111111111115111111111111111111111155555000000000000000000000000000011111111111111110111000000
55555555550000000000005111111111111111111111111111111111111111111111115550000000011111111100000000000111111111111111111111000011
11111155550000000000051111111111111111111100000000111111111111111111111000000011111111111111110000001111111111111111111555111111
11111111111111100000555555111111111111100000000000000111111111111111110000001111111111111111111000111111111111111111155551111110
11111111111111110555555555551111111110000000000000000001111111111111110000011111111111111111111100111111111111111111511111110000
11111111111111100000000000555511111100000000000000000000011111111111100000111111111111111111111111111111111111111111111111111111
11111155555555000000000000000011150000000000000000000000001111111111100001111111111111111111555555111111111111111111111111111111
11111155555555000000000000000011150000000000000000000000001111111111100001111111111111111111555555111111111111111111111111111111
11115555555500000000000000000001500000000000111111111000011111111111100111111111111111111155555555555111111111111555555555111111
15555555550000000000000000000000000000000011111111111111111111111111111111111111111111111115555555555551111111155555555555551111
55555555500000000000000000000000000000000111111111111111111111111111111111111111111111111111555555555555511155555555555555555551
55550000000000000000000000000000000000111111111111111111155555555111111111111111111111111111115555555555555555500555555555555500
50000000000000000000000000000000000000011111111111111155555555555555111111111111111111111111111555555555555555555500555555550000
00000000000000000000000000000000000000000111111111111555555555555555511111111111111111111111110005555555555555555555055555000000
00000000000000000000000000000000000000000111111111111555555555555555511111111111111111111111110005555555555555555555055555000000
00000000000000000000000000000001111111100011111111555555555555555555555551111111111111111111111111111111155555555555550555000000
00000000000000000000000000011111111111111111111111555555555555555555555555511111111111111111111111111111111155555555555550000001
50001000000000000555555555111111111111111111111115555111111111555555555555551111111111111111111111111111111111555555555555555555
55001110000000055555555555551111111111111111111111111555555555115555555555555551111111111111111555111111111111115555555555555555
11111111111055555555550000000001111111111155555555115555555555551555555555551111111111111111111111555511111111155555555555551111
11111111111111155500000000000000001111155555555555555555555555555155555555511111111111111111111111115551111111555555555555111111
11111111111111155500000000000000001111155555555555555555555555555155555555511111111111111111111111115551111111555555555555111111
11111111111111115000000000000000000011555555555555555555555555555511555551111111111111111111111111111155551155555555555111111111
11111111111111111100000000000000000005555555555555555555555555555555155111111111111111111111111111111115555555555555551111111111
11111111111111111111000000000000000000555555555555555000000555555555551111111111111111111111111111111111155555555555555111111111
11111111111111111111100000000005555555555555555555000000000000550000001111111111111111111111111111111111155555555555555551111111
11111511111111111111100005555555555555555555555555555000000000000000011111111111551111111111111111111115555555555555555555511111
11111511111111111111100005555555555555555555555555555000000000000000011111111111551111111111111111111115555555555555555555511111
11111111111111111111115555555555555555555551111111115550000000000000001111111155511111111111111111111111155555555555555000000000
11111111111111111111155555555555555555555111111111111155550000000000555555555555111111111111111111111111115555555555000000000000
11111111111111111111555555555555555555555551111111111111155000005555555555555555111111111111111111111111111555555500000000000000
11111111111111111155555555555555555555555555111111111111115500055555555555555555511111111111111111111111111155555000000000000000
11111111111111111111111111155555555555555555551111111111111555555555555555555555551111111111111111111111111155550000000000000000
11111111111111111111111111111110000005555555551111111111111155555555555555555555555555555155555555001111111155500111111111000000
11111111111111111111111111111110000005555555551111111111111155555555555555555555555555555155555555001111111155500111111111000000
11111111111111111111111111111111000000000000000011111111111555555555555555555555555555555555111115555111110000111111111111111100
11111111111111111111111111111111110000000001111111111111115555555555555555555555555555555555551111115511100011111111111111111110
01111111111111111111111111111111111100011111111111111111155555555555555555555555555555555555555111111550001111111111111111111111
00111111111111111111111111111111111110111111111111111111155555551555555555555555555555555555555511111155511111111111111111111111
00111111111111111111111111111111111111111111111111111111111111111111555555555555555555555555555551115551111111111111111111111111
00001111111111111111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555511111111111111111
00001111111111111111111111111111111111111111111111111111111111111111111555555555555555555555555555555555555555511111111111111111
00001111111111111111111111111111111111111111111111111111111111111111111115555555555555555555555555555555555555555111111111111111
00001111111111111111111111111111111111111111110000000011111111111111111111555555555555555555555555555555555555555555511111111111
00111111111111111111111555555555111111111100000000000000001111111111111111111111115555555511111155555555555555555555555555555551
01111111111111111111555555555555555511111000000000000000000111111111111111111111111115511111111155555555555555511111111555555555
11111111111111111155555555555555555551000000000000000000000000111111111111111111111111111111111555555555555511111111111111555555
11111111111111111555555555555555555555000000000000000000000000011111111111111111111111111111115555555555551111111111111111115555
11111111111111111555555555555555555555000000000000000000000000011111111111111111111111111111115555555555551111111111111111115555
11111111111111115555555555555555555555500000000000000000000000001111111111111111111111111111115555555555511111111111111111111115
11111111111111111555555555555555555555555000000000000000000000001111111111111111111111111111555555555551111111111111111555555500

