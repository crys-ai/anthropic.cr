require "../spec_helper"

describe Anthropic::Metadata do
  describe "#initialize" do
    it "creates with no params" do
      metadata = Anthropic::Metadata.new
      metadata.user_id.should be_nil
      metadata.custom.should be_nil
    end

    it "creates with user_id only" do
      metadata = Anthropic::Metadata.new(user_id: "user-123")
      metadata.user_id.should eq("user-123")
      metadata.custom.should be_nil
    end

    it "creates with custom fields only" do
      custom = {"session_id" => JSON::Any.new("abc"), "tier" => JSON::Any.new("premium")}
      metadata = Anthropic::Metadata.new(custom: custom)
      metadata.user_id.should be_nil
      metadata.custom.should eq(custom)
    end

    it "creates with both user_id and custom" do
      custom = {"app_version" => JSON::Any.new("1.0.0")}
      metadata = Anthropic::Metadata.new(user_id: "user-456", custom: custom)
      metadata.user_id.should eq("user-456")
      metadata.custom.should eq(custom)
    end
  end

  describe ".with_user_id" do
    it "creates metadata with only user_id" do
      metadata = Anthropic::Metadata.with_user_id("user-789")
      metadata.user_id.should eq("user-789")
      metadata.custom.should be_nil
    end
  end

  describe "#to_json" do
    it "serializes empty metadata to empty object" do
      metadata = Anthropic::Metadata.new
      json = metadata.to_json
      JSON.parse(json).as_h.should be_empty
    end

    it "serializes user_id" do
      metadata = Anthropic::Metadata.new(user_id: "user-123")
      json = metadata.to_json
      parsed = JSON.parse(json)
      parsed["user_id"].as_s.should eq("user-123")
    end

    it "serializes custom fields" do
      custom = {"session_id" => JSON::Any.new("abc123"), "count" => JSON::Any.new(42_i64)}
      metadata = Anthropic::Metadata.new(custom: custom)
      json = metadata.to_json
      parsed = JSON.parse(json)
      parsed["session_id"].as_s.should eq("abc123")
      parsed["count"].as_i.should eq(42)
    end

    it "serializes user_id and custom fields together" do
      custom = {"app" => JSON::Any.new("myapp")}
      metadata = Anthropic::Metadata.new(user_id: "user-999", custom: custom)
      json = metadata.to_json
      parsed = JSON.parse(json)
      parsed["user_id"].as_s.should eq("user-999")
      parsed["app"].as_s.should eq("myapp")
    end

    it "does not include user_id when nil" do
      metadata = Anthropic::Metadata.new
      json = metadata.to_json
      json.should_not contain("user_id")
    end
  end
end

describe Anthropic::Messages::Request do
  describe "metadata param" do
    it "accepts metadata in initialize" do
      metadata = Anthropic::Metadata.new(user_id: "user-123")
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        metadata: metadata
      )
      request.metadata.should eq(metadata)
    end

    it "defaults metadata to nil" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      request.metadata.should be_nil
    end

    it "serializes metadata to JSON" do
      metadata = Anthropic::Metadata.new(user_id: "user-456")
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        metadata: metadata
      )
      json = request.to_json
      parsed = JSON.parse(json)
      parsed["metadata"]["user_id"].as_s.should eq("user-456")
    end

    it "omits metadata field when nil" do
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024
      )
      json = request.to_json
      json.should_not contain("metadata")
    end

    it "copies metadata in with_stream" do
      metadata = Anthropic::Metadata.new(user_id: "user-789")
      request = Anthropic::Messages::Request.new(
        model: Anthropic::Model.sonnet,
        messages: [Anthropic::Message.user("Hello!")],
        max_tokens: 1024,
        metadata: metadata
      )

      stream_request = request.with_stream(true)
      stream_request.metadata.should eq(metadata)
      stream_request.stream.should be_true
    end
  end
end
