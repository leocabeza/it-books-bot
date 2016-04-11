require 'telegram/bot'
require 'httparty'
require 'json'
require 'open-uri'
require 'yaml'

config = YAML.load_file('config.yml')
base_url = 'http://it-ebooks-api.info/v1/'

Telegram::Bot::Client.run(config['telegram_key']) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Hello, #{message.from.first_name}, " << 
          "to start searching for books, use the command /search " <<
          "passing the name of the book as a parameter"
        )
    when '/help'
      bot.api.send_message(chat_id: message.chat.id, text: "Available commands: /search")
    when /^\/[0-9]+$/
      response = HTTParty.get("#{base_url}book/#{message.text}")
      if (response.code == 200) 
       book_detail = JSON.parse(response.body)
        if (book_detail['Error'] == '0')
          bot.api.send_message(
            chat_id: message.chat.id,
            text: "Here you go: " <<
              "#{book_detail['Title']} (#{book_detail['Year']}) by " <<
              "#{book_detail['Author']} " <<
              "#{book_detail['Download']}"
          )
        else
          bot.api.send_message(
            chat_id: message.chat.id,
            text: "The book was not found, please try again later"
          )
        end
      else
       bot.api.send_message(
         chat_id: message.chat.id,
         text: "There was an error trying to communicate with It-Ebooks. " <<
           "Please try again later"
       )
      end
    when /search/i
      array_param = message.text.split
      array_param.shift
      query_param = URI::encode(array_param.join(' '))

      if (query_param.length > 51)
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Sorry, I can only search books with less than 50 characters"
        )
      else 
        response = HTTParty.get("#{base_url}search/#{query_param}")
        if (response.code == 200) 
          json = JSON.parse(response.body)
          if (json['Error'] == '0' && json['Total'] != '0')
            filtered_books = json['Books']
            question = "Which of these books are you trying to download?\n\n"
            filtered_books.each do |book|
              question << "/#{book['ID']} - #{book['Title']} - #{book['SubTitle']}\n"
            end
            bot.api.send_message(
              chat_id: message.chat.id,
              text: question,
              disable_web_page_preview: true
            )
          else
            bot.api.send_message(
              chat_id: message.chat.id,
              text: "I couldn't find any books with the title '#{query_param}'"
            )            
          end
        else
          bot.api.send_message(
            chat_id: message.chat.id,
            text: "There was an error trying to communicate with It-Ebooks. " <<
              "Please try again later"
          )
        end
      end
    end
    puts "Response to question #{message.text} sent to @#{message.chat.username}"
  end
end
