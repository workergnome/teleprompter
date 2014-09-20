# Initialize libraries
express = require('express')
http = require('http')
request = require('request')
faye = require('faye')
_ = require('lodash')
util = require('util')
fs = require('fs')

# Set up the HTTP server.  (Special to support Faye)
app = express()
server = http.createServer(app)
app.use (err, req, res, next) ->
    console.error(err.stack);
    res.send(500);

# Set up Faye
bayeux = new faye.NodeAdapter({mount: '/faye', timeout: 45});
bayeux.attach(server)
bayeux.on 'handshake', (clientId) ->
    console.log 'Client connected', clientId 

client = new faye.Client('http://localhost:3000/faye')

# Global arrays for tracking the words
expected_words = []
spoken_words = []

# Word Lists
ignore_these_words = ["utorrent", "definition", "synonym", "generator", "itunes", "tumblr", "download", "verizon", "twitter", "promo", "lyrics", "youtube", "yahoo", "wiki", "images", "english", "netflix", "song", "recipe", "snl", "imdb", "ebay"]#, "the", "be", "to", "of", "and", "a", "in", "that", "have", "i", "it", "for", "not", "on", "with", "he", "as", "you", "do", "at", "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all", "would", "there", "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "me", "when", "make", "can", "like", "time", "no", "just", "him", "know", "take", "person", "into", "year", "your", "good", "some", "could", "them", "see", "other", "than", "then", "now", "look", "only", "come", "its", "over", "think", "also", "back", "after", "use", "two", "how", "our", "work", "first", "well", "way", "even", "new", "want", "because", "any", "these", "give", "day", "most", "us"]
dont_ignore_these_words = ["a","i", "I"]

# Given a text of previously said works and a google suggestion,
# return up to three new words 
getNextWord = (text,suggestion)->
  return false if suggestion.length == 1 && !_.contains(dont_ignore_these_words,suggestion)
  return false if suggestion.search(/\d/) != -1


  words = text.toLowerCase().split(" ")
  new_words = suggestion.toLowerCase().split(" ")
  
  # ignore bad words
  for word in ignore_these_words
    _.pull(new_words, word)
  # ignore previously said words
  for word in words
    _.pull(new_words,word) 
  if new_words.length == 0
    return false
  else
    return _.first(new_words,3).join(" ")

# Async request for search results from google.  
# the magic number 4 is how far in the past to use the words
# the magic number 10 is how many previously said words to ignore
# return fuck to prevent infinite loops
# return "I" because there are no suggestions for fuck.
getGoogleSuggestion = (text, long_text, callback) =>
  long_text = text unless long_text
  console.log "trying with '#{text}'"
  if text == "" || text == " " || text == "fuck"
    expected_words = []
    spoken_words = []
    if  text == "fuck"
      callback ("I")
    else
      callback("fuck") 
    return false
  short_text = _.last(text.split(" "),4).join(" ")
  text = _.last(long_text.split(" "),10).join(" ")
  url = "http://suggestqueries.google.com/complete/search?client=firefox&q=\"#{short_text}\""
  request url,  (error, response, body) =>
    if (!error && response.statusCode == 200) 
      next = false
      suggestion = ""

      console.log JSON.parse(body)
      suggestions = _.shuffle(JSON.parse(body)[1])
      for suggestion in suggestions
        next = getNextWord(text,suggestion)
        break if next
      if next == false
        words = short_text.split(" ")
        words.shift()
        getGoogleSuggestion(words.join(" "), text, callback)
      else
        callback(next)

# Callback for the previous method—takes the next word, and returns it to the browser
handle_google_suggestion  = (next_word) =>
    words = next_word.split(" ")
    expected_words.push word for word in words
    client.publish "/prompt_with", {word: _.first(expected_words), sentence: spoken_words}
    console.log "expected_words: #{expected_words}"
    console.log "spoken_words: #{spoken_words}"


# Left over from the CFG in the ruby code.  Not currently used.
client.subscribe "/handled_word", (msg)->
  console.log msg
  if msg.usable
    client.publish '/response', msg.sentence
  else
    getSuggestion msg.search_term


# Handler for new words from the browser—
# if it's the word you expect, just give the next word.
# otherwise, get a new word.  
# uses pub-sub to call the next method, not just a method call
# because some of the implementations of it were in ruby.
client.subscribe '/spoke', (said_word)=>
  said_word=said_word.trim()
  console.log "'#{_.first(expected_words)}','#{said_word}'"
  if _.first(expected_words) == said_word
    console.log "expected"
    spoken_words.push expected_words.shift()
    client.publish "/prompt_with", {word: _.first(expected_words), sentence: spoken_words}

    if expected_words.length == 0
      client.publish("/request_next_word",{word:  spoken_words.join(" "), search_term: spoken_words.join(" ")})    
  else
    expected_words = []
    spoken_words = _.last(spoken_words,1)
    spoken_words.push(said_word)
    client.publish("/request_next_word",{word:  said_word, search_term: spoken_words.join(" ")})

# Listener for the event in the previous method
client.subscribe "/request_next_word", (obj) =>
  getGoogleSuggestion(obj.word,obj.spoken_words,handle_google_suggestion)

# Serve up the index.html file
app.get '/', (req, res) ->
  res.sendfile('index.html')

# Serve up the javascript
app.get '/app.js', (req,res) ->
  res.sendfile('app.js')

# Fire up the system.
server.listen 3000, () ->
  console.log 'listening on *:3000'
