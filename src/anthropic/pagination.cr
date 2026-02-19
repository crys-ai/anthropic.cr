require "json"
require "uri"

# Generic page response for cursor-based list endpoints.
# T is the type of items in the data array.
struct Anthropic::Page(T)
  include JSON::Serializable

  getter data : Array(T)
  getter? has_more : Bool
  getter first_id : String?
  getter last_id : String?

  def initialize(
    @data : Array(T) = [] of T,
    @has_more : Bool = false,
    @first_id : String? = nil,
    @last_id : String? = nil,
  )
  end

  # Iterates over all items on this page.
  def each(& : T ->) : Nil
    @data.each { |item| yield item }
  end

  # Returns true if this page has no items.
  def empty? : Bool
    @data.empty?
  end

  # Returns the number of items on this page.
  def size : Int32
    @data.size
  end
end

# Parameters for list requests with pagination.
struct Anthropic::ListParams
  getter limit : Int32?
  getter before_id : String?
  getter after_id : String?

  def initialize(
    @limit : Int32? = nil,
    @before_id : String? = nil,
    @after_id : String? = nil,
  )
    if l = @limit
      raise ArgumentError.new("limit must be positive, got #{l}") unless l > 0
    end
    if @before_id && @after_id
      raise ArgumentError.new(
        "before_id and after_id are mutually exclusive; set only one per request"
      )
    end
  end

  # Builds query string for pagination parameters using query-component encoding.
  def to_query_string : String
    result = URI::Params.build do |builder|
      if l = @limit
        builder.add("limit", l.to_s)
      end
      if bid = @before_id
        builder.add("before_id", bid)
      end
      if aid = @after_id
        builder.add("after_id", aid)
      end
    end
    result.empty? ? "" : "?#{result}"
  end
end

# Auto-paginating iterator for cursor-based list endpoints.
# Takes a fetcher proc that retrieves a single page and iterates
# across all pages automatically using after_id cursor tokens.
#
# Example:
# ```
# paginator = client.files.list_all(limit: 20)
# paginator.each do |file|
#   puts file.filename
# end
# ```
class Anthropic::AutoPaginator(T)
  include Enumerable(T)

  @fetcher : Proc(ListParams, Page(T))
  @initial_limit : Int32?

  # Creates a new auto-paginator with the given fetcher proc.
  # The fetcher should accept ListParams and return a Page(T).
  def initialize(fetcher : Proc(ListParams, Page(T)), initial_limit : Int32? = nil)
    @fetcher = fetcher
    @initial_limit = initial_limit
  end

  # Creates a new auto-paginator with a block.
  # The block should accept ListParams and return a Page(T).
  def initialize(*, limit : Int32? = nil, &fetcher : ListParams -> Page(T))
    @fetcher = fetcher
    @initial_limit = limit
  end

  # Iterates over all items across all pages.
  # Fetches pages lazily using after_id cursor until has_more? is false.
  def each(& : T ->) : Nil
    after_id : String? = nil

    loop do
      params = ListParams.new(limit: @initial_limit, after_id: after_id)
      page = @fetcher.call(params)

      # Yield all items from current page
      page.data.each { |item| yield item }

      # Stop if no more pages
      break unless page.has_more?

      # Get cursor for next page
      if last = page.last_id
        # Guard against non-advancing cursor (would loop forever)
        if last == after_id
          raise PaginationError.new("Pagination cursor did not advance: last_id '#{last}' is the same as the previous cursor. This indicates a server-side issue.")
        end
        after_id = last
      else
        # has_more is true but no cursor to continue — fail fast
        raise PaginationError.new(
          "Server indicated more pages (has_more=true) but did not provide a last_id cursor. " \
          "Cannot continue pagination."
        )
      end
    end
  end

  # Returns all items as an array (fetches all pages eagerly).
  def to_a : Array(T)
    items = [] of T
    each { |item| items << item }
    items
  end
end
