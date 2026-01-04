// This file has valid syntax, but calls a missing function
// It should PASS syntax check (-o nul) but FAIL runtime check
function update() {
    Graphics.update(); // Graphics is not defined here
}
var x = $gamePlayer.x; // $gamePlayer is not defined here
