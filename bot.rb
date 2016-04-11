require 'telegram/bot'
require 'yaml'
require './lib/bot/it_ebook.rb'

config = YAML.load_file('config.yml')

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
      bot.api.send_message(
        chat_id: message.chat.id,
        text: "Available commands: /search"
      )
    when /^\/[0-9]+$/
      begin
        book = Bot::Book.find(message.text)
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Here you go:\n " <<
            "#{book.title} (#{book.year}) by " <<
            "#{book.author} " <<
            "#{book.download}"
        )
      rescue Bot::NoBookFoundError => e
        bot.api.send_message(
          chat_id: message.chat.id,
          text: e.message
        )
      rescue Bot::BadConnectionError => e
        bot.api.send_message(
          chat_id: message.chat.id,
          text: e.message
        )
      end
    when /search/i
      array_param = message.text.split
      array_param.shift
      query_param = array_param.join(' ')

      begin
        books = Bot::Book.search(query_param)
        question = "Which of these books are you trying to download?\n\n"
        books.each do |book|
          question << "/#{book.id} - #{book.title} "
          question << "- #{book.sub_title}" if book.respond_to?(:sub_title)
          question << "\n"
        end
        bot.api.send_message(
          chat_id: message.chat.id,
          text: question,
          disable_web_page_preview: true
        )
      rescue Bot::QueryTooLongError => e
        bot.api.send_message(
          chat_id: message.chat.id,
          text: e.message
        )
      rescue Bot::NoBookFoundError => e
        bot.api.send_message(
          chat_id: message.chat.id,
          text: e.message
        )
      rescue Bot::BadConnectionError => e
        bot.api.send_message(
          chat_id: message.chat.id,
          text: e.message
        )
      end
    end
    puts "Response to question #{message.text} sent to @#{message.chat.username}"
  end
end
