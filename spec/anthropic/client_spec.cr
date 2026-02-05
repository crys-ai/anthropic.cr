require "../spec_helper"

describe Anthropic::Client do
  describe "#initialize" do
    it "raises without API key" do
      TestHelpers.with_env("ANTHROPIC_API_KEY", nil) do
        expect_raises(ArgumentError, /API key required/) do
          Anthropic::Client.new
        end
      end
    end

    it "accepts explicit API key" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.api_key.should eq("sk-ant-test")
    end

    it "reads from environment" do
      TestHelpers.with_env("ANTHROPIC_API_KEY", "sk-ant-from-env") do
        client = Anthropic::Client.new
        client.api_key.should eq("sk-ant-from-env")
      end
    end

    it "uses default base URL" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.base_url.should eq("https://api.anthropic.com")
    end

    it "allows custom base URL" do
      client = Anthropic::Client.new(api_key: "sk-ant-test", base_url: "https://custom.api")
      client.base_url.should eq("https://custom.api")
    end
  end

  describe "#messages" do
    it "returns Messages::API" do
      client = Anthropic::Client.new(api_key: "sk-ant-test")
      client.messages.should be_a(Anthropic::Messages::API)
    end
  end
end
