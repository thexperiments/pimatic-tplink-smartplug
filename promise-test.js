var Promise = require ('bluebird');

var EventEmitter = require("events").EventEmitter;
 
var ee = new EventEmitter();

var waitID = 0;
var waitDef;

ee.on("someEvent", function (id) {
    console.log("event " + id + " has occured");
});
 
setTimeout(function emitEvent(){
  ee.emit("someEvent", 1);
  },
  1000
);

setTimeout(function emitEvent(){
  ee.emit("someEvent", 2);
  },
  2000
);

setTimeout(function emitEvent(){
  ee.emit("someEvent", 3);
  },
  3000
);

function waitForEvent(id){
  var def = Promise.pending();
  ee.once('someEvent', function (eventId){
    if(id == eventId){
      //the right event has happened
      console.log('right event');
      def.resolve();
    }
    else{
      //not the right event, keep waiting
      console.log('not the right event');
      def.resolve(waitForEvent(id));
    }
  });
  return def.promise;
};

var waitingPromise = waitForEvent(2).timeout(5000, 'timed out').then(
  function(){
    console.log('promise fulfilled because of right event');
  },
  function(err){
    console.log('promise failed:' + err);
  }
);

console.log('waiting...');

