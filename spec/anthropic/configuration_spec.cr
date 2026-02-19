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

    it "accepts custom retry policy" do
      policy = Anthropic::RetryPolicy.new(max_retries: 5)
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", retry_policy: policy)
      config.retry_policy.max_retries.should eq(5)
    end

    it "accepts beta headers" do
      betas = ["tools-1.0", "max-tokens-3.0"]
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", beta_headers: betas)
      config.beta_headers.should eq(betas)
    end
  end

  describe "defensive copies" do
    it "does not mutate stored beta_headers when original array is modified" do
      original = ["tools-1.0", "max-tokens-3.0"]
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", beta_headers: original)

      original << "injected-header"

      config.beta_headers.should eq(["tools-1.0", "max-tokens-3.0"])
      config.beta_headers.size.should eq(2)
    end

    it "does not leak internal beta_headers via getter" do
      config = Anthropic::Configuration.new(
        api_key: "sk-ant-test",
        beta_headers: ["original"]
      )
      # Mutating the returned array should not affect internal state
      config.beta_headers << "injected"
      config.beta_headers.should eq(["original"])
    end
  end

  describe "default retry policy and beta headers" do
    it "has default retry policy" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test")
      config.retry_policy.max_retries.should eq(2)
      config.retry_policy.enabled?.should be_true
    end

    it "has empty beta headers by default" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test")
      config.beta_headers.should be_empty
    end
  end

  describe "validation" do
    it "raises ArgumentError for zero timeout" do
      expect_raises(ArgumentError, /timeout must be positive/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", timeout: 0.seconds)
      end
    end

    it "raises ArgumentError for negative timeout" do
      expect_raises(ArgumentError, /timeout must be positive/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", timeout: -1.seconds)
      end
    end

    it "raises ArgumentError for zero pool size" do
      expect_raises(ArgumentError, /max_pool_size must be positive/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", max_pool_size: 0)
      end
    end

    it "raises ArgumentError for negative pool size" do
      expect_raises(ArgumentError, /max_pool_size must be positive/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", max_pool_size: -1)
      end
    end

    it "accepts positive timeout" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", timeout: 1.seconds)
      config.timeout.should eq(1.seconds)
    end

    it "accepts positive pool size" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", max_pool_size: 1)
      config.max_pool_size.should eq(1)
    end

    it "raises ArgumentError for empty base_url" do
      expect_raises(ArgumentError, /base_url must not be empty/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "")
      end
    end

    it "raises ArgumentError for whitespace-only base_url" do
      expect_raises(ArgumentError, /base_url must not be empty/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "   ")
      end
    end

    it "raises ArgumentError for missing scheme in base_url" do
      expect_raises(ArgumentError, /base_url must use http or https scheme/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "api.anthropic.com")
      end
    end

    it "raises ArgumentError for unsupported scheme in base_url" do
      expect_raises(ArgumentError, /base_url must use http or https scheme/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "ftp://api.anthropic.com")
      end
    end

    it "raises ArgumentError for missing host in base_url" do
      expect_raises(ArgumentError, /base_url must have a host/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://")
      end
    end

    it "accepts valid https base_url" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com")
      config.base_url.should eq("https://api.anthropic.com")
    end

    it "accepts valid http base_url" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "http://localhost")
      config.base_url.should eq("http://localhost")
    end

    it "accepts base_url with port" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "http://localhost:8080")
      config.base_url.should eq("http://localhost:8080")
    end

    it "accepts base_url with port 443" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com:443")
      config.base_url.should eq("https://api.anthropic.com:443")
    end

    it "raises ArgumentError for base_url with port 0" do
      expect_raises(ArgumentError, /port must be in range 1\.\.65535, got 0/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com:0")
      end
    end

    it "raises ArgumentError for base_url with port 65536" do
      expect_raises(ArgumentError, /port must be in range 1\.\.65535, got 65536/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com:65536")
      end
    end

    it "raises ArgumentError for base_url with port 99999" do
      expect_raises(ArgumentError, /port must be in range 1\.\.65535, got 99999/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com:99999")
      end
    end

    it "raises ArgumentError for host with embedded space" do
      expect_raises(ArgumentError, /whitespace or control characters/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api anthropic.com")
      end
    end

    it "raises ArgumentError for host with tab character" do
      expect_raises(ArgumentError, /whitespace or control characters/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api\tanthropic.com")
      end
    end

    it "raises ArgumentError for host with control character" do
      expect_raises(ArgumentError, /whitespace or control characters/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api\x01anthropic.com")
      end
    end

    it "accepts base_url with leading/trailing whitespace after trimming" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "  https://api.anthropic.com  ")
      config.base_url.should eq("https://api.anthropic.com")
    end

    it "raises ArgumentError for base_url with path" do
      expect_raises(ArgumentError, /no path/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com/v1")
      end
    end

    it "raises ArgumentError for base_url with query string" do
      expect_raises(ArgumentError, /query string/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com?key=val")
      end
    end

    it "raises ArgumentError for base_url with fragment" do
      expect_raises(ArgumentError, /fragment/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com#section")
      end
    end

    it "raises ArgumentError for base_url with userinfo" do
      expect_raises(ArgumentError, /userinfo/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://user:pass@api.anthropic.com")
      end
    end

    it "accepts base_url with trailing slash" do
      config = Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://api.anthropic.com/")
      config.base_url.should eq("https://api.anthropic.com/")
    end

    # URI.parse failure normalization: parse exceptions are wrapped as ArgumentError
    # so that ALL base_url validation failures produce consistent error semantics.

    it "raises ArgumentError (not URI::Error) for base_url with non-numeric port" do
      # Crystal's URI.parse raises URI::Error for non-numeric port values
      expect_raises(ArgumentError, /base_url is not a valid URL/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://host:not_a_port")
      end
    end

    it "raises ArgumentError (not URI::Error) for base_url with negative port" do
      expect_raises(ArgumentError, /base_url is not a valid URL/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://host:-1")
      end
    end

    it "raises ArgumentError (not URI::Error) for base_url with mixed port" do
      # "123abc" triggers URI::Error: bad port
      expect_raises(ArgumentError, /base_url is not a valid URL/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://host:123abc")
      end
    end

    it "raises ArgumentError (not OverflowError) for base_url with overflowing port" do
      # An extremely large port number triggers OverflowError in URI.parse
      expect_raises(ArgumentError, /base_url is not a valid URL/) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "http://host:99999999999999")
      end
    end

    it "preserves original error context in the message for parse failures" do
      error = expect_raises(ArgumentError) do
        Anthropic::Configuration.new(api_key: "sk-ant-test", base_url: "https://host:abc")
      end
      if msg = error.message
        msg.should contain("base_url is not a valid URL")
        # The original parse error detail (e.g., "bad port") should be preserved
        msg.should contain("bad port")
      end
    end
  end
end
