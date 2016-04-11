require 'httparty'
require 'open-uri'
require_relative './version.rb'

module Bot
  class Book include HTTParty

    base_uri 'http://it-ebooks-api.info/v1/'

    def initialize attrs
      attrs.each do |name, val|
        if name == 'ID'
          lower_camel_cased = 'id'
        elsif name == 'ISBN'
          lower_camel_cased = 'isbn'
        else
          lower_camel_cased = name.gsub(/(.)([A-Z])/,'\1_\2').downcase
        end
        instance_variable_set "@#{lower_camel_cased}", val

        define_singleton_method lower_camel_cased.to_sym do
          instance_variable_get "@#{lower_camel_cased}"
        end
      end
    end

    class << self
      def find(id)
        response = get("/book/#{id.to_s}")
        if (response.code == 200)
          parsed = response.parsed_response

          if (parsed['Error'] == '0')
            parsed.delete 'Error'
            parsed.delete 'Time'

            self.new parsed
          else
            raise NoBookFoundError
          end
        else
          raise ConnectionErrorError
        end
      end

      def search(query)
        if (query.length > 51)
          raise QueryTooLongError
        else
          encoded_query = URI::encode(query)
          response = get("/search/#{encoded_query}")
          if (response.code == 200)
            parsed = response.parsed_response
            if (parsed['Error'] == '0' &&
              parsed['Total'] != '0')
                parsed['Books'].map { |b| self.new b}
            else
              raise NoBookFoundError
            end
          else
            raise BadConnectionError
          end
        end
      end
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
  class ConnectionErrorError < StandardError
    def initialize(msg="There was an error " <<
      " trying to communicate with It-Ebooks. " <<
      "Please try again later")
      super
    end
  end
end