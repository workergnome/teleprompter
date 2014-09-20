require 'moby'
require 'faye'

class Grammar
  attr_accessor :emitted, :stack, :pos
  def initialize
    @rules = {
      :S =>  {0 => [:NP, :VP]},
      :VP => {0 => [:VERB, :NP], 1 => [:VERB, :NP, :PP]},
      :PP => {0 => [:P, :NP]},
      :NP => {0 => [:PROPER], 1 => [:Det, :NOUN], 2=> [:Det, :NOUN, :PP]},
    }

    @pos = Moby::PartsOfSpeech.new
    
    @autofill_types = [:Det, :P]
    @madlib_types = [:NOUN,:PROPER, :VERB]
    
    @prepositions =  %W{aboard about above across after against along amid among anti around as at before behind below beneath beside besides between beyond but by concerning considering despite down during except excepting excluding following for from in inside into like minus near of off on onto opposite outside over past per plus regarding round save since than through to toward towards under underneath unlike until up upon versus via with within without}
    @determiners =   %W{a an another any certain each every her his its my no our some that the their this}

    @emitted = []
    @stack = []
  end  


  def begin
    process_rule(:S)
  end

  def process_rule(rule)
   # puts "processing #{rule}"
    if @autofill_types.include?(rule) 
      case rule
        when :Det then @emitted.push @determiners.sample
        when :P then @emitted.push @prepositions.sample
      end
    elsif @madlib_types.include?(rule)
      @stack.unshift(rule)
    else
      add_to_stack rule    
    end
  end

  def add_to_stack(rule)
    if @rules[rule].keys.count == 1
      @rules[rule][@rules[rule].keys.first].reverse.each {|r| @stack.unshift(r)}
      process_rule(@stack.shift)
    else 
      @stack.unshift rule
    end
  end

  def process_word(word)
    word_type = case
      when @pos.verb?(word) then :VERB
      when @pos.noun?(word) then :NOUN
      else :PROPER
    end
    puts word_type
    is_valid = check_validity(@stack.first,word_type)
    if is_valid
      next_rule = @stack.shift
      phrase = next_valid(next_rule, word_type)
      phrase.each do |p|
        if p == word_type
          @emitted.push word
        else 
          process_rule(p)
        end
      end
    else 
     # puts "No valid options!"
      return false
    end
  end

  def check_validity(val, next_part, depth = 0)
    return nil if depth == 4
    val = [val] if val.is_a? Symbol 
    result = val.collect do |i|
      if i == next_part 
        true 
      elsif @madlib_types.include? i
        false
      elsif @rules.keys.include? i 
        !@rules[i].find{|key,value| check_validity(value, next_part, depth+1)}.nil?
      else 
        nil
      end
    end.compact
    result.first
  end
  
  def next_valid(part,next_part)
    search = @rules[part].clone
    while search.size > 0
      choice = search.delete(search.keys.sample)
      return choice if check_validity(choice,next_part) 
    end  
    return nil
  end

  def get_word
    case rand(3)
    when 0 then @pos.nouns.sample
    when 1 then @pos.verbs.sample
    when 2 then ["David","Lauren","Kyle","Golan"].sample
    end
  end
end


# g = Grammar.new
# g.begin
# while g.stack.size > 0
#   word = g.get_word
#   #puts "Trying #{word}:"
#   g.process_word(word)
#   #puts "EMITTED: #{g.emitted}, STACK: #{g.stack}"
# end
# puts g.emitted.join " "


g = Grammar.new
g.begin
while g.stack.size > 0
  puts g.emitted.join " "
  type = 
  puts "I neeed a #{ g.stack.first == :NP ? "noun" : "verb"}  (#{g.stack.first})"
  word = $stdin.gets.chomp
  #puts "Trying #{word}:"
  g.process_word(word)
  #puts "EMITTED: #{g.emitted}, STACK: #{g.stack}"
end

puts "COMPLETE!"
puts g.emitted.join " "


# require 'eventmachine'

# EM.run {
#   client = Faye::Client.new('http://localhost:3000/faye')
#   g = Grammar.new

#   client.subscribe('/process_new_word') do |message|
#     word = message["word"].strip

#     puts "I am looking for a sentence starting with #{word}.  it is a #{g.pos.find(word).inspect}  MY current stack is #{g.stack}"
#     if g.stack.size == 0
#       g.emitted = []
#       g.begin  
#     end
#     usable = g.process_word(word)
    
#     sentence = g.emitted.join(" ")
#     #g.emitted = []
#     sentence = sentence + "." if g.stack.size == 0
#     client.publish('/handled_word', 'usable' => usable, "sentence" => sentence, search_term: message["search_term"])
#   end
# }





