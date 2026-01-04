var LibB = {
    greet: function() { return LibA.greet() + " via LibB"; }
};
console.log("Loaded LibB");
