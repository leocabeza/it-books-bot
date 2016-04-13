require 'telegram/bot'
require './lib/bot/it_ebook.rb'

token = YAML::load(IO.read('config/secrets.yml'))['telegram_token']

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::Message
      keyboard = [
        Telegram::Bot::Types::InlineKeyboardButton
          .new(
            text: 'Send books to friends',
            switch_inline_query: 'ruby'
          )
      ]
      markup = Telegram::Bot::Types::InlineKeyboardMarkup
        .new(inline_keyboard: keyboard)
      bot.api.send_message(
        chat_id: message.chat.id,
        parse_mode: 'html',
        text: "Hello, #{message.from.first_name}, " << 
          "I can help you to find and download books. " <<
          "You can call it up from any of your chats by typing " <<
          "@itbooksbot  <i>something</i> in the message field",
        reply_markup: markup
      )
    when Telegram::Bot::Types::InlineQuery
      begin
        results = []
        if (message.query.length > 2)
          books = Bot::Book.search(message.query)
          books.each do |book|
            find_book = Bot::Book.find(book.id)
            result = Telegram::Bot::Types::InlineQueryResultPhoto.new(
              id: find_book.id,
              photo_url: find_book.image,
              thumb_url: find_book.image,
              disable_web_page_preview: true,
              caption: "Here you go:\n " <<
                "#{find_book.title} (#{find_book.year}) by " <<
                "#{find_book.author} " <<
                "#{find_book.download}"
            )
            results.push(result)
          end
        end
        bot.api.answer_inline_query(inline_query_id: message.id, results: results)
      rescue Exception => e
        puts e.message
      end
    when Telegram::Bot::Types::CallbackQuery
      begin
        book = Bot::Book.find(message.data)
        bot.api.send_message(
          chat_id: message.from.id,
          text: "Here you go:\n " <<
            "#{book.title} (#{book.year}) by " <<
            "#{book.author} " <<
            "#{book.download}"
        )
      rescue Bot::NoBookFoundError => e
        bot.api.send_message(
          chat_id: message.from.id,
          text: e.message
        )
      rescue Bot::BadConnectionError => e
        bot.api.send_message(
          from_id: message.from.id,
          text: e.message
        )
      end
    else
      puts 'Unsupported operation'
    end
  end
end
