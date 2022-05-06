console.log("i am NOT god");

//note: you cannot set gpio pins to a negative value

//general info
var pico_8_frog_id = -1;

//talking with pico 8
var pico8_gpio = new Array(128);

let pico_started = false;

let vals = new Array(10)
let decay_rate = 1;

let gamestate_pin_start = 1

let input_pin = 100
let id_pin = 101

let prev_input_val = 0;     //for detecting change

//talking with backend
var socket;

//var remote_adress = "ws://ssdj-game.herokuapp.com:80";
//uncomment this line to test locally
var remote_adress = "ws://localhost:3001";

console.log("try to connect to "+remote_adress)

socket = new WebSocket(remote_adress);
//things to happen once socket is connected
socket.onopen = function(event) {
  console.log("SOCKET OPEN");
};

socket.onmessage = function(event) {
    process_msg(event.data);
};

function setup(){
    //alert(pico8_gpio[0]);
    //pico8_gpio[3] = 10;
    for (let i=0; i<vals.length; i++){
        vals[i] = 100;
    }
}

function update(){
    //check if pico 8 has launched
    if (!pico_started){
        if (pico8_gpio[0]){
            pico_started = true
            console.log("pico 8 started!")

            //if we already heard from the backend, set our ID
            if (pico_8_frog_id != -1){
                pico8_gpio[id_pin] = pico_8_frog_id;
            }
        }
         //boucce out if we're not connected yet
        else{
            return;
        }
    }
    
    //console.log("hi "+pico8_gpio[input_pin])

    //check if the player has changed input
    let cur_input_val = pico8_gpio[input_pin];
    if (cur_input_val != prev_input_val){
        console.log("input change: "+cur_input_val)
        let val = {
            type: "input_change",
            val: cur_input_val
        };
        socket.send(JSON.stringify(val));

        prev_input_val = cur_input_val;
    }

    /*
    //sometimes trigger a higher value
    if (Math.random() < 0.1){
        //console.log("set da value")
        let id = Math.floor(Math.random()*vals.length);
        vals[id] = 100 + Math.random() * 100;
        //console.log(id+":"+ vals[id])
    }
    
    //set all values
    for (let i=0; i<vals.length; i++){
        vals[i] -= decay_rate
        if (vals[i] < 0)    vals[i] = 0
        pico8_gpio[i] = vals[i]
    }
    */
}

function process_msg(data){
    //console.log("got something:")
    //console.log(data)

    let msg = data;
    try {
        msg = JSON.parse(data);
    } catch (e) {
        console.log("BAD! not json: " + msg);
        return;
    }

    if (msg.type == "connect_confirm"){
        console.log("set it to "+msg.frog_id)
        pico_8_frog_id = msg.frog_id + 1;   //pico8 is 1 indexed
        //set the pin (this will need to be redone if pico8 has not started yet)
        pico8_gpio[id_pin] = pico_8_frog_id  
    }

    if (msg.type == "gamestate"){
        //console.log(msg.frog_vals)
        for (let i=0; i<msg.frog_vals.length; i++){
            pico8_gpio[gamestate_pin_start+i] = msg.frog_vals[i].val
            if (!msg.frog_vals[i].active){
                pico8_gpio[gamestate_pin_start+i] = 250
            }
        }
    }
    
}

setup();
setInterval(update, 100);