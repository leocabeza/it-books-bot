require 'telegram_bot'
require 'httparty'
require 'json'
require 'open-uri'
require 'yaml'

config = YAML.load_file('config.yml')
bot = TelegramBot.new(token: config['telegram_key'])
bot.get_updates(fail_silently: true) do |message|
  puts "@#{message.from.username}: #{message.text}"
  url = 'http://it-ebooks-api.info/v1/'
  command = message.get_command_for(bot)

  message.reply do |reply|
    case command
    when /search/i
      array_param = command.split
      array_param.shift
      query_param = URI::encode(array_param.join(' '))
      puts query_param
      if (query_param.length > 51)
        reply.text = "Sorry, I can only search books with less than 50 characters"
      else 
        response = HTTParty.get("#{url}search/#{query_param}")
        if (response.code == 200) 
          json = JSON.parse(response.body)
          if (json['Total'] == "0")
            reply.text = "I couldn't find any books with the text #{query_param}"
          else
            book = json['Books'][0]
            puts book
            response = HTTParty.get("#{url}book/#{book['ID']}")
            if (response.code == 200) 
              book_detail = JSON.parse(response.body)
              reply.text = "This is the best match I could get: " <<
              "#{book_detail['Title']} (#{book_detail['Year']}) by " <<
              "#{book_detail['Author']}" <<
              "#{book_detail['Download']}"
            else
              reply.text = "There was an error trying to communicate with It-Ebooks. " <<
                "Please try again later"
            end
          end
        else
          reply.text = "There was an error trying to communicate with It-Ebooks. " <<
            "Please try again later"
        end
      end
    else
      reply.text = "#{message.from.first_name}, have no idea what #{command.inspect} means."
    end
    puts "sending #{reply.text.inspect} to @#{message.from.username}"
    reply.send_with(bot)
  end
end