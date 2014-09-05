app = require('express')()
http = require('http').Server(app)
io = require('socket.io')(http)
request = require('request')
_ = require('lodash')

getNextWord = (text,suggestion)->
  return false if suggestion.length == 1
  return false if suggestion.search(/\d/) != -1

  common_words = ["lyrics", "the", "be", "to", "of", "and", "a", "in", "that", "have", "i", "it", "for", "not", "on", "with", "he", "as", "you", "do", "at", "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all", "would", "there", "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "me", "when", "make", "can", "like", "time", "no", "just", "him", "know", "take", "person", "into", "year", "your", "good", "some", "could", "them", "see", "other", "than", "then", "now", "look", "only", "come", "its", "over", "think", "also", "back", "after", "use", "two", "how", "our", "work", "first", "well", "way", "even", "new", "want", "because", "any", "these", "give", "day", "most", "us"]

  words = text.toLowerCase().split(" ")
  new_words = suggestion.toLowerCase().split(" ")
  
  for word in common_words
    _.pull(new_words, word)
  for word in words
    _.pull(new_words,word) 
  if new_words.length == 0
    return false
  else
    return new_words[0]

getSuggestion = (text, callback, long_text = false) ->
  long_text = text unless long_text
  console.log "trying with '#{text}'"
  return if text == " "
  short_text = _.last(text.split(" "),5).join(" ")
  text = _.last(long_text.split(" "),8).join(" ")
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
        getSuggestion(words.join(" "), callback, text)
      else
        callback("<span class='suggestion'>#{suggestion} </span><br/> #{next}")
    else


app.get '/', (req, res) ->
  res.sendfile('index.html')

io.on 'connection', (socket) ->
  socket.on 'prompt', (msg)->
    console.log "\n\n\n\n--------"
    getSuggestion msg,(msg) ->
      io.emit 'response', msg

http.listen 3000, () ->
  console.log 'listening on *:3000'
