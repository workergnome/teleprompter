
// Set up speech recognition part
var recognition = new webkitSpeechRecognition();
window.debounceString = ""
recognition.continuous = true;
recognition.interimResults = true;
recognition.lang = "en-US";

recognition.onstart = function() { console.log("goooooo!"); }
recognition.onresult = function(event) {
  result = _.last(event.results);
  word = result[0].transcript;
  confidence = result[0].confidence;
  isFinal = result.isFinal;
  // debug info
  console.log(event.results);
  console.log("Word: '" + word + "', debounce: '" + window.debounceString + "', confidence: "+ confidence +", is final:" + isFinal);
  // end debug

  if (window.debounceString != word && (confidence > 0.005 || isFinal)){
      window.debounceString = word
      client.publish('/spoke', _.last(word.split(" ")));
   }
}

// mention errors
recognition.onerror = function(event) { console.log("ERROR:",event); }

// restart if it stops
recognition.onend = function() { 
  console.log("restarted!");
  recognition.start();
}

// Initialize the socket communication
var client = new Faye.Client('/faye');

// Prevent form submissions
$("form").on('submit', function(e){
  e.preventDefault();
})

//  Handle submissions on keypress
$('#m').on('keyup', function(e){
   e.preventDefault();
  if (e.keyCode == 32 || e.keyCode == 13) {
    client.publish('/spoke', $('#m').val());
    $('#m').val("")
  }
  return false;
});

// Handle responses from the server
client.subscribe('/prompt_with', function(msg){
  $('#messages').html(msg.word);
  $('#sentence').html(msg.sentence.join(" "));
});

// begin listening
recognition.start();

// UNused text-to-speech
/*
        var speech = new SpeechSynthesisUtterance(msg.word);
  speech.onend = function(e) {
    console.log('Finished in ' + event.elapsedTime + ' seconds.');
    window.setTimeout("client.publish('/spoke', $('#messages').text());",500);
  };

  speechSynthesis.speak(speech);
*/