require 'httparty'
require 'open-uri'
require_relative './version.rb'
require 'pp'

module Bot
  class Book
    include HTTParty

    base_uri 'http://it-ebooks-api.info/v1/'

    def initialize attrs
      attrs.each do |name, val|
        lower_camel_cased = underscore(name)
        instance_variable_set "@#{lower_camel_cased}", val

        define_singleton_method lower_camel_cased.to_sym do
          instance_variable_get "@#{lower_camel_cased}"
        end
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

        self.new book
      end

      def search(query)
        if (query.length > 50)
          raise QueryTooLongError
        else
          get_books(query).map{ |b| self.new b}
        end
      end

      private

      def get_books(query)
        encoded_query = URI::encode(query)
        books = get_request("/search/#{encoded_query}")
        if (books['Total'] == '0')
          raise NoBookFoundError
        else
          books['Books']
        end
      end

      def get_request(url)
        response = get(url)
        if(response.code == 200)
          parsed = response.parsed_response
          if (parsed['Error'] == '0') # means OK
            parsed
          else
            raise ApiError, parsed['Error']
          end
        else
          raise BadConnectionError
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
  class NoBookFoundError < StandardError
    def initialize(msg="I couldn't find any books " <<
      " with the title given")
      super
    end
  end
  class BadConnectionError < StandardError
    def initialize(msg="There was an error " <<
      " trying to communicate with It-Ebooks. " <<
      "Please try again later")
      super
    end
  end
end