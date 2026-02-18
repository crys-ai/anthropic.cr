require "../spec_helper"

describe Anthropic::Configuration do
  describe "default values" do
    it "uses default base URL" do
      TestHelpers.with_env("ANTHROPIC_BASE_URL", nil) do
        config = Anthropic::Configuration.new(api_key: "sk-ant-test")
        config.base_url.should eq("https://api.anthropic.com")
      end
    end

    it "uses default API version" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test")
      config.api_version.should eq("2023-06-01")
    end

    it "uses default timeout of 120 seconds" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test")
      config.timeout.should eq(120.seconds)
    end

    it "uses default pool size of 10" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test")
      config.max_pool_size.should eq(10)
    end
  end

  describe "env var loading" do
    it "reads ANTHROPIC_API_KEY from environment" do
      TestHelpers.with_env("ANTHROPIC_API_KEY", "sk-ant-from-env") do
        config = Anthropic::Configuration.new
        config.api_key.should eq("sk-ant-from-env")
      end
    end

    it "reads ANTHROPIC_BASE_URL from environment" do
      TestHelpers.with_env("ANTHROPIC_BASE_URL", "https://custom.proxy.com") do
        config = Anthropic::Configuration.new(api_key: "sk-ant-test")
        config.base_url.should eq("https://custom.proxy.com")
      end
    end
  end

  describe "missing API key" do
    it "raises ArgumentError when no API key is provided" do
      TestHelpers.with_env("ANTHROPIC_API_KEY", nil) do
        expect_raises(ArgumentError, /API key required/) do
          Anthropic::Configuration.new
        end
      end
    end
  end

  describe "custom values override defaults" do
    it "accepts explicit API key" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-custom")
      config.api_key.should eq("sk-ant-custom")
    end

    it "explicit API key overrides env var" do
      TestHelpers.with_env("ANTHROPIC_API_KEY", "sk-ant-from-env") do
        config = Anthropic::Configuration.new(api_key: "sk-ant-explicit")
        config.api_key.should eq("sk-ant-explicit")
      end
    end

    it "accepts custom base URL" do
      TestHelpers.with_env("ANTHROPIC_BASE_URL", nil) do
        config = Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://my-proxy.com")
        config.base_url.should eq("https://my-proxy.com")
      end
    end

    it "accepts custom API version" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", api_version: "2024-01-01")
      config.api_version.should eq("2024-01-01")
    end

    it "accepts custom timeout" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", timeout: 30.seconds)
      config.timeout.should eq(30.seconds)
    end

    it "accepts custom pool size" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", max_pool_size: 5)
      config.max_pool_size.should eq(5)
    end
  end
end
