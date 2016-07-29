require 'httparty'
require_relative './version.rb'

module Bot
  class Book
    include HTTParty

    base_uri 'http://it-ebooks-api.info/v1/'

    def initialize attrs, total, page
      attrs.each do |name, val|
        lower_camel_cased = underscore(name)
        instance_variable_set "@#{lower_camel_cased}", val

        define_singleton_method lower_camel_cased.to_sym do
          instance_variable_get "@#{lower_camel_cased}"
        end
      end

      instance_variable_set "@total", total
      instance_variable_set "@page", page

      define_singleton_method :total do
        instance_variable_get "@total"
      end
      define_singleton_method :page do
        instance_variable_get "@page"
      end
    end

    private

    def underscore(word)
      modified_word = word.dup
      modified_word.gsub!(/::/, '/')
      modified_word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      modified_word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
      modified_word.tr!("-", "_")
      modified_word.downcase!
      modified_word
    end

    class << self
      def find(id)
        book = get_request("/book/#{id.to_s}")
        book.delete 'Error'
        book.delete 'Time'

        self.new book, 1, 1
      end

      def search(query, page=1)
        if (query.length > 50)
          raise QueryTooLongError
        elsif (query.length == 0)
          raise QueryNullError
        else
          books = get_books(query, page)
          books['Books'].map do |b|
            self.new b, books['Total'], books['Page']
          end
        end
      end

      def get_book_info(book)
        format_book_info(book)
      end

      private

      def get_books(query, page=1)
        search_url = "/search/#{query}"
        search_url << "/page/#{page}" if page != 1
        books = get_request(search_url)
        if (books['Total'] == '0')
          raise NoBookFoundError
        else
          books
        end
      end

      def format_book_info(book)
        msg = "\nHere you go:\n " <<
          "#{book.image}\n<b>#{book.title}</b> (#{book.year}) by " <<
          "<i>#{book.author}</i> " <<
          "\n\n<a href='#{book.download}'>Download here</a>"
        msg
      end

      def get_request(url)
        response = get(url)
        if(response.code == 200)
          parsed = parse_response(response)
          if (parsed['Error'] == '0') # means OK
            parsed
          else
            raise ApiError, parsed['Error']
          end
        else
          raise BadConnectionError
        end
      end

      def parse_response(response)
        begin
          response.parsed_response
        rescue JSON::ParserError
          JSON.parse(response.body.gsub(/(?<=[^:,\{])"(?=[^:,\}])/, '*'))
        end
      end
    end
  end

  class ApiError < StandardError
    def initialize(msg)
      super
    end
  end

  class QueryTooLongError < StandardError
    def initialize(msg="Sorry, I can only search books " <<
      "with less than 50 characters")
      super
    end
  end
  class QueryNullError < StandardError
    def initialize(msg="Sorry, I can only find books " <<
      "with an actual name")
      super
    end
  end
  class NoBookFoundError < StandardError
    def initialize(msg="I couldn't find any books " <<
      "with the title given")
      super
    end
  end
  class NoQueryError < StandardError
    def initialize(msg="No query has been provided " <<
      "for the search")
    end
  end
  class BadConnectionError < StandardError
    def initialize(msg="There was an error " <<
      "trying to communicate with It-Ebooks. " <<
      "Please try again later")
      super
    end
  end
end
