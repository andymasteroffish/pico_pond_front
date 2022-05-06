console.log("i am god");
var pico8_gpio = new Array(128);

function setup(){
    alert(pico8_gpio[0]);
    pico8_gpio[3] = 10;
}

function update(){
    console.log("hi "+pico8_gpio[2])
}

setup();
setInterval(update, 1000);