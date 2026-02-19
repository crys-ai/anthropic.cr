class Anthropic::EventSource
  struct Message
    getter event : String
    getter data : Array(String)
    getter id : String?

    def initialize(@event = "message", @data = [] of String, @id = nil)
    end
  end

  @abort = false
  @on_message : Proc(Message, self, Nil)? = nil
  getter last_id : String? = nil

  def initialize(@io : IO)
  end

  def on_message(&block : Message, self ->) : self
    @on_message = block
    self
  end

  def stop : Nil
    @abort = true
  end

  def run : Nil
    lines = [] of String

    loop do
      break if @abort
      break unless line = @io.gets

      if line.empty? && !lines.empty?
        @on_message.try &.call(parse_message(lines), self)
        lines.clear
      else
        lines << line
      end
    end

    # EOF flush: handle stream ending without trailing blank line
    # (some servers close connection without sending final \n\n)
    if !lines.empty?
      @on_message.try &.call(parse_message(lines), self)
    end
  end

  private def parse_message(lines : Array(String)) : Message
    event = "message"
    data = [] of String
    id = nil

    lines.each do |line|
      case
      when line.starts_with?("event:") then event = strip_sse_value(line[6..])
      when line.starts_with?("data:")  then data << strip_sse_value(line[5..])
      when line.starts_with?("id:")    then id = strip_sse_value(line[3..])
      when line.starts_with?("retry:") then nil # ignore
      when line.starts_with?(":")      then nil # comment
      end
    end

    @last_id = id unless id.nil?
    Message.new(event: event, data: data, id: id)
  end

  # Strips exactly one leading space from a field value, per SSE spec.
  # The SSE specification says: "If value is not the empty string and
  # its first character is a U+0020 SPACE character, remove it."
  private def strip_sse_value(value : String) : String
    value.starts_with?(' ') ? value[1..] : value
  end
end
