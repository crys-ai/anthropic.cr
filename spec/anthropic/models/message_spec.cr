require "../../spec_helper"

describe Anthropic::Message do
  describe ".user" do
    it "creates user message" do
      msg = Anthropic::Message.user("Hello!")
      msg.role.should eq(Anthropic::Message::Role::User)
      msg.content.should eq("Hello!")
    end

    it "handles empty content" do
      msg = Anthropic::Message.user("")
      msg.content.should eq("")
    end

    it "handles multiline content" do
      msg = Anthropic::Message.user("Line 1\nLine 2")
      msg.content.should eq("Line 1\nLine 2")
    end
  end

  describe ".assistant" do
    it "creates assistant message" do
      msg = Anthropic::Message.assistant("Hi!")
      msg.role.should eq(Anthropic::Message::Role::Assistant)
      msg.content.should eq("Hi!")
    end

    it "handles complex responses" do
      content = "Here's a code example:\n```\nputs 'hello'\n```"
      msg = Anthropic::Message.assistant(content)
      msg.content.should eq(content)
    end
  end

  describe "Role enum" do
    it "has user role" do
      Anthropic::Message::Role::User.to_s.should eq("User")
    end

    it "has assistant role" do
      Anthropic::Message::Role::Assistant.to_s.should eq("Assistant")
    end
  end

  describe "JSON" do
    it "serializes role as lowercase" do
      msg = Anthropic::Message.user("Hello!")
      json = msg.to_json
      json.should contain(%("role":"user"))
      json.should contain(%("content":"Hello!"))
    end

    it "serializes assistant role as lowercase" do
      msg = Anthropic::Message.assistant("Hi!")
      json = msg.to_json
      json.should contain(%("role":"assistant"))
    end

    it "handles special characters in content" do
      msg = Anthropic::Message.user("Hello \"world\"!")
      json = msg.to_json
      json.should contain("Hello \\\"world\\\"!")
    end

    it "roundtrips user message" do
      original = Anthropic::Message.user("Test message")
      json = original.to_json
      restored = Anthropic::Message.from_json(json)
      restored.role.should eq(original.role)
      restored.content.should eq(original.content)
    end

    it "roundtrips assistant message" do
      original = Anthropic::Message.assistant("Response text")
      json = original.to_json
      restored = Anthropic::Message.from_json(json)
      restored.role.should eq(original.role)
      restored.content.should eq(original.content)
    end
  end
end
