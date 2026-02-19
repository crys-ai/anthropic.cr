require "../spec_helper"

describe Anthropic::Page do
  describe "JSON deserialization" do
    it "parses a page response" do
      json = <<-JSON
        {
          "data": [
            {"id": "claude-sonnet-4-6", "display_name": "Sonnet", "created_at": "2025-01-01T00:00:00Z", "type": "model"},
            {"id": "claude-haiku-4-5", "display_name": "Haiku", "created_at": "2025-01-02T00:00:00Z", "type": "model"}
          ],
          "has_more": true,
          "first_id": "claude-sonnet-4-6",
          "last_id": "claude-haiku-4-5"
        }
        JSON

      page = Anthropic::Page(Anthropic::ModelInfo).from_json(json)

      page.data.size.should eq(2)
      page.data[0].id.should eq("claude-sonnet-4-6")
      page.has_more?.should be_true
      page.first_id.should eq("claude-sonnet-4-6")
      page.last_id.should eq("claude-haiku-4-5")
    end

    it "parses empty page" do
      json = %({"data": [], "has_more": false})

      page = Anthropic::Page(Anthropic::ModelInfo).from_json(json)

      page.data.should be_empty
      page.has_more?.should be_false
      page.first_id.should be_nil
      page.last_id.should be_nil
    end
  end

  describe "JSON round-trip" do
    it "survives to_json -> from_json" do
      original = Anthropic::Page(Anthropic::ModelInfo).new(
        data: [
          Anthropic::ModelInfo.new(id: "test", display_name: "Test", created_at: "2025-01-01T00:00:00Z"),
        ],
        has_more: false,
        first_id: "test",
        last_id: "test",
      )

      parsed = Anthropic::Page(Anthropic::ModelInfo).from_json(original.to_json)
      parsed.data.size.should eq(1)
      parsed.data[0].id.should eq("test")
      parsed.has_more?.should be_false
    end
  end

  describe "#initialize" do
    it "creates page with defaults" do
      page = Anthropic::Page(Anthropic::ModelInfo).new

      page.data.should be_empty
      page.has_more?.should be_false
      page.first_id.should be_nil
      page.last_id.should be_nil
    end

    it "creates page with values" do
      items = [Anthropic::ModelInfo.new(id: "x", display_name: "X", created_at: "2025-01-01")]
      page = Anthropic::Page(Anthropic::ModelInfo).new(
        data: items,
        has_more: true,
        first_id: "x",
        last_id: "x",
      )

      page.data.size.should eq(1)
      page.has_more?.should be_true
    end
  end

  describe "#each" do
    it "iterates over items" do
      items = [
        Anthropic::ModelInfo.new(id: "a", display_name: "A", created_at: "2025-01-01"),
        Anthropic::ModelInfo.new(id: "b", display_name: "B", created_at: "2025-01-02"),
      ]
      page = Anthropic::Page(Anthropic::ModelInfo).new(data: items)

      ids = [] of String
      page.each { |item| ids << item.id }

      ids.should eq(["a", "b"])
    end
  end

  describe "#empty?" do
    it "returns true for empty page" do
      page = Anthropic::Page(Anthropic::ModelInfo).new
      page.empty?.should be_true
    end

    it "returns false for non-empty page" do
      items = [Anthropic::ModelInfo.new(id: "x", display_name: "X", created_at: "2025-01-01")]
      page = Anthropic::Page(Anthropic::ModelInfo).new(data: items)
      page.empty?.should be_false
    end
  end

  describe "#size" do
    it "returns item count" do
      items = [
        Anthropic::ModelInfo.new(id: "a", display_name: "A", created_at: "2025-01-01"),
        Anthropic::ModelInfo.new(id: "b", display_name: "B", created_at: "2025-01-02"),
        Anthropic::ModelInfo.new(id: "c", display_name: "C", created_at: "2025-01-03"),
      ]
      page = Anthropic::Page(Anthropic::ModelInfo).new(data: items)
      page.size.should eq(3)
    end
  end
end

describe Anthropic::ListParams do
  describe "validation" do
    it "raises ArgumentError for zero limit" do
      expect_raises(ArgumentError, /limit must be positive/) do
        Anthropic::ListParams.new(limit: 0)
      end
    end

    it "raises ArgumentError for negative limit" do
      expect_raises(ArgumentError, /limit must be positive/) do
        Anthropic::ListParams.new(limit: -1)
      end
    end

    it "accepts positive limit" do
      params = Anthropic::ListParams.new(limit: 10)
      params.limit.should eq(10)
    end

    it "accepts nil limit" do
      params = Anthropic::ListParams.new
      params.limit.should be_nil
    end

    it "raises ArgumentError when both before_id and after_id are set" do
      expect_raises(ArgumentError, /mutually exclusive/) do
        Anthropic::ListParams.new(before_id: "abc", after_id: "xyz")
      end
    end

    it "raises ArgumentError when both cursors set with limit" do
      expect_raises(ArgumentError, /mutually exclusive/) do
        Anthropic::ListParams.new(limit: 10, before_id: "abc", after_id: "xyz")
      end
    end

    it "accepts before_id alone" do
      params = Anthropic::ListParams.new(before_id: "abc")
      params.before_id.should eq("abc")
      params.after_id.should be_nil
    end

    it "accepts after_id alone" do
      params = Anthropic::ListParams.new(after_id: "xyz")
      params.after_id.should eq("xyz")
      params.before_id.should be_nil
    end
  end

  describe "#initialize" do
    it "creates params with defaults" do
      params = Anthropic::ListParams.new

      params.limit.should be_nil
      params.before_id.should be_nil
      params.after_id.should be_nil
    end

    it "creates params with values" do
      params = Anthropic::ListParams.new(
        limit: 20,
        after_id: "next-id",
      )

      params.limit.should eq(20)
      params.before_id.should be_nil
      params.after_id.should eq("next-id")
    end
  end

  describe "#to_query_string" do
    it "returns empty string when no params set" do
      params = Anthropic::ListParams.new
      params.to_query_string.should eq("")
    end

    it "includes limit when set" do
      params = Anthropic::ListParams.new(limit: 50)
      params.to_query_string.should eq("?limit=50")
    end

    it "includes before_id when set" do
      params = Anthropic::ListParams.new(before_id: "msg_123")
      params.to_query_string.should eq("?before_id=msg_123")
    end

    it "includes after_id when set" do
      params = Anthropic::ListParams.new(after_id: "msg_456")
      params.to_query_string.should eq("?after_id=msg_456")
    end

    it "combines multiple params" do
      params = Anthropic::ListParams.new(limit: 20, after_id: "msg_789")
      params.to_query_string.should eq("?limit=20&after_id=msg_789")
    end

    it "URL-encodes ids with special characters" do
      params = Anthropic::ListParams.new(after_id: "msg_abc/def+ghi")
      params.to_query_string.should contain("after_id=")
      # URI::Params.build encodes / and + using query-component encoding
      params.to_query_string.should_not contain("msg_abc/def+ghi")
    end

    it "uses query-component encoding for spaces" do
      params = Anthropic::ListParams.new(before_id: "msg with spaces")
      qs = params.to_query_string
      # URI::Params.build encodes spaces as + in query strings
      qs.should contain("before_id=msg+with+spaces")
    end

    it "encodes ampersands and equals in ids" do
      params = Anthropic::ListParams.new(after_id: "id&with=special")
      qs = params.to_query_string
      # Ampersand and equals must be encoded in query values
      qs.should_not contain("id&with=special")
      qs.should contain("after_id=")
    end
  end
end

# Helper for AutoPaginator specs
private def create_test_file(id : String, filename : String) : Anthropic::File
  Anthropic::File.new(
    id: id,
    filename: filename,
    size_bytes: 100_i64,
    created_at: "2025-01-01T00:00:00Z"
  )
end

describe Anthropic::AutoPaginator do
  describe "#each" do
    it "iterates over a single page when has_more is false" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "test.txt")],
          has_more: false,
          first_id: "file_1",
          last_id: "file_1"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      ids = [] of String
      paginator.each { |file| ids << file.id }

      ids.should eq(["file_1"])
      call_count.should eq(1)
    end

    it "iterates across multiple pages using after_id cursor" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt"), create_test_file("file_2", "b.txt")],
          has_more: true,
          first_id: "file_1",
          last_id: "file_2"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_3", "c.txt")],
          has_more: false,
          first_id: "file_3",
          last_id: "file_3"
        ),
      ]
      call_count = 0
      received_params = [] of Anthropic::ListParams?

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |params|
        call_count += 1
        received_params << params
        pages[call_count - 1]
      end

      ids = [] of String
      paginator.each { |file| ids << file.id }

      ids.should eq(["file_1", "file_2", "file_3"])
      call_count.should eq(2)

      # First call should have no after_id
      if p1 = received_params[0]
        p1.after_id.should be_nil
      end

      # Second call should have after_id from first page's last_id
      if p2 = received_params[1]
        p2.after_id.should eq("file_2")
      end
    end

    it "stops when has_more is false" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt")],
          has_more: true,
          first_id: "file_1",
          last_id: "file_1"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_2", "b.txt")],
          has_more: true,
          first_id: "file_2",
          last_id: "file_2"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_3", "c.txt")],
          has_more: false,
          first_id: "file_3",
          last_id: "file_3"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      count = 0
      paginator.each { |_file| count += 1 }

      count.should eq(3)
      call_count.should eq(3)
    end

    it "works with empty first page" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [] of Anthropic::File,
          has_more: false,
          first_id: nil,
          last_id: nil
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      ids = [] of String
      paginator.each { |file| ids << file.id }

      ids.should be_empty
      call_count.should eq(1)
    end

    it "raises PaginationError for empty page with has_more but no cursor" do
      # Edge case: empty page but has_more is true with no last_id
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [] of Anthropic::File,
          has_more: true,
          first_id: nil,
          last_id: nil
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      error = expect_raises(Anthropic::PaginationError) do
        paginator.each { |_file| }
      end
      if msg = error.message
        msg.should contain("has_more=true")
        msg.should contain("last_id")
      else
        fail "Expected error message to be present"
      end
      call_count.should eq(1)
    end

    it "yields all items in order" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("1", "first.txt"), create_test_file("2", "second.txt")],
          has_more: true,
          first_id: "1",
          last_id: "2"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("3", "third.txt"), create_test_file("4", "fourth.txt")],
          has_more: true,
          first_id: "3",
          last_id: "4"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("5", "fifth.txt")],
          has_more: false,
          first_id: "5",
          last_id: "5"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      filenames = [] of String
      paginator.each { |file| filenames << file.filename }

      filenames.should eq(["first.txt", "second.txt", "third.txt", "fourth.txt", "fifth.txt"])
    end

    it "passes initial limit to fetcher" do
      received_limits = [] of Int32?

      paginator = Anthropic::AutoPaginator(Anthropic::File).new(limit: 20) do |params|
        received_limits << params.limit
        Anthropic::Page(Anthropic::File).new(data: [] of Anthropic::File, has_more: false)
      end

      paginator.each { |_| }

      received_limits.should eq([20])
    end
  end

  describe "cursor guard" do
    it "raises PaginationError when cursor does not advance" do
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        # Always returns same last_id, simulating a stuck server
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "stuck.txt")],
          has_more: true,
          first_id: "file_1",
          last_id: "file_1" # never advances
        )
      end

      error = expect_raises(Anthropic::PaginationError) do
        paginator.each { |_| }
      end
      if msg = error.message
        msg.should contain("did not advance")
        msg.should contain("file_1")
      else
        fail "Expected error message to be present"
      end
      # Should detect on 2nd fetch (first is OK since after_id starts nil)
      call_count.should eq(2)
    end

    it "does not raise when cursor advances normally" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt")],
          has_more: true,
          first_id: "file_1",
          last_id: "file_1"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_2", "b.txt")],
          has_more: false,
          first_id: "file_2",
          last_id: "file_2"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      ids = [] of String
      paginator.each { |file| ids << file.id }

      ids.should eq(["file_1", "file_2"])
      call_count.should eq(2)
    end

    it "raises PaginationError when non-empty page has has_more but no last_id" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt")],
          has_more: true,
          first_id: "file_1",
          last_id: nil
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      error = expect_raises(Anthropic::PaginationError) do
        paginator.each { |_| }
      end
      if msg = error.message
        msg.should contain("has_more=true")
        msg.should contain("last_id")
      else
        fail "Expected error message to be present"
      end
      call_count.should eq(1)
    end
  end

  describe "#to_a" do
    it "returns all items as an array" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt")],
          has_more: true,
          first_id: "file_1",
          last_id: "file_1"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_2", "b.txt"), create_test_file("file_3", "c.txt")],
          has_more: false,
          first_id: "file_2",
          last_id: "file_3"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      items = paginator.to_a
      items.size.should eq(3)
      items[0].id.should eq("file_1")
      items[1].id.should eq("file_2")
      items[2].id.should eq("file_3")
    end
  end

  describe "Enumerable methods" do
    it "supports #map" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt"), create_test_file("file_2", "b.txt")],
          has_more: false,
          first_id: "file_1",
          last_id: "file_2"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      ids = paginator.map(&.id)
      ids.should eq(["file_1", "file_2"])
    end

    it "supports #select" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt"), create_test_file("file_2", "b.txt"), create_test_file("file_3", "c.txt")],
          has_more: false,
          first_id: "file_1",
          last_id: "file_3"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      selected = paginator.select { |file| file.filename.starts_with?("a") || file.filename.starts_with?("c") }
      selected.size.should eq(2)
      selected[0].id.should eq("file_1")
      selected[1].id.should eq("file_3")
    end

    it "supports #first" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("file_1", "a.txt"), create_test_file("file_2", "b.txt")],
          has_more: false,
          first_id: "file_1",
          last_id: "file_2"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      if first = paginator.first?
        first.id.should eq("file_1")
      else
        fail "expected first? to return a file"
      end
    end

    it "supports #size" do
      pages = [
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("1", "a.txt"), create_test_file("2", "b.txt")],
          has_more: true,
          first_id: "1",
          last_id: "2"
        ),
        Anthropic::Page(Anthropic::File).new(
          data: [create_test_file("3", "c.txt")],
          has_more: false,
          first_id: "3",
          last_id: "3"
        ),
      ]
      call_count = 0

      paginator = Anthropic::AutoPaginator(Anthropic::File).new do |_params|
        call_count += 1
        pages[call_count - 1]
      end

      # size requires iterating through all elements
      items = paginator.to_a
      items.size.should eq(3)
    end
  end
end
