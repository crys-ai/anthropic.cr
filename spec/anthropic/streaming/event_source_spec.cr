require "../../spec_helper"

describe Anthropic::EventSource do
  it "parses SSE events" do
    input = IO::Memory.new(<<-SSE)
      event: message_start
      data: {"type":"message_start"}

      event: content_block_delta
      data: {"type":"delta","text":"Hello"}

      SSE

    events = [] of NamedTuple(event: String, data: Array(String))

    Anthropic::EventSource.new(input)
      .on_message { |msg, _| events << ({event: msg.event, data: msg.data}) }
      .run

    events.size.should eq 2
    events[0][:event].should eq "message_start"
    events[1][:event].should eq "content_block_delta"
  end

  it "handles EOF without trailing blank line" do
    # Some servers close without final \n\n
    input = IO::Memory.new("event: test\ndata: {}")
    events = [] of NamedTuple(event: String, data: Array(String))

    Anthropic::EventSource.new(input)
      .on_message { |msg, _| events << ({event: msg.event, data: msg.data}) }
      .run

    events.size.should eq 1
  end

  it "stops when abort is called" do
    input = IO::Memory.new("event: test\ndata: {}\n\nevent: test\ndata: {}\n\n")
    count = 0

    es = Anthropic::EventSource.new(input)
    es.on_message do |_, _|
      count += 1
      es.stop if count >= 1
    end
    es.run

    count.should eq 1
  end

  it "parses multiline data" do
    input = IO::Memory.new(<<-SSE)
      event: message
      data: line1
      data: line2

      SSE

    events = [] of NamedTuple(event: String, data: Array(String))

    Anthropic::EventSource.new(input)
      .on_message { |msg, _| events << ({event: msg.event, data: msg.data}) }
      .run

    events.size.should eq 1
    events[0][:event].should eq "message"
    events[0][:data].should eq(["line1", "line2"])
  end

  it "parses id field" do
    input = IO::Memory.new(<<-SSE)
      id: msg-123
      data: test

      SSE

    es = Anthropic::EventSource.new(input)
    es.on_message { |_, _| }
    es.run

    es.last_id.should eq "msg-123"
  end

  it "ignores comment lines" do
    input = IO::Memory.new(<<-SSE)
      : this is a comment
      data: test

      SSE

    events = [] of NamedTuple(event: String, data: Array(String))

    Anthropic::EventSource.new(input)
      .on_message { |msg, _| events << ({event: msg.event, data: msg.data}) }
      .run

    events.size.should eq 1
  end

  it "ignores retry field" do
    input = IO::Memory.new(<<-SSE)
      retry: 1000
      data: test

      SSE

    events = [] of NamedTuple(event: String, data: Array(String))

    Anthropic::EventSource.new(input)
      .on_message { |msg, _| events << ({event: msg.event, data: msg.data}) }
      .run

    events.size.should eq 1
  end
end
