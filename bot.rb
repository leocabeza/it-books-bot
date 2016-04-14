require 'telegram/bot'
require './lib/bot/it_ebook.rb'

token = YAML::load(IO.read('config/secrets.yml'))['telegram_token']

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::ChosenInlineResult
      puts message
    when Telegram::Bot::Types::CallbackQuery
      # this is only for button and pagination
      begin
        book = Bot::Book.search(message.data)
        bot.api.send_message(
          chat_id: message.from.id,
          text: "Here you go:\n " <<
            "#{book.title} (#{book.year}) by " <<
            "#{book.author} " <<
            "#{book.download}"
        )
      rescue Exception => e
        bot.api.send_message(
          chat_id: message.from.id,
          text: e.message
        )
      end
    when Telegram::Bot::Types::Message
      case message.text
      when '/start'
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Hello, #{message.from.first_name}, " << 
            "to start searching for books, use the command /search "
        )
      when '/help'
        bot.api.send_message(
          chat_id: message.chat.id,
          text: 'Available commands: /search'
        )
      when /^\/[0-9]+$/
        begin
          book = Bot::Book.find(message.text)
          keyboard = [
            Telegram::Bot::Types::InlineKeyboardButton
              .new(text: 'Download', url: book.download)
          ]
          markup = Telegram::Bot::Types::InlineKeyboardMarkup
            .new(inline_keyboard: keyboard)
          result = Telegram::Bot::Types::InlineQueryResultPhoto.new(
            id: book.id,
            photo_url: book.image,
            thumb_url: book.image,
            disable_web_page_preview: true,
            caption: "#{book.title} (#{book.year}) by " <<
              "#{book.author}",
            reply_markup: markup
          )
          bot.api.answer_inline_query(
            inline_query_id: message.chat.id,
            result: [result]
          )
        rescue Bot::Exception => e
          bot.api.send_message(
            chat_id: message.chat.id,
            text: e.message
          )
        end
      when /^\/search/i
        reply_markup = Telegram::Bot::Types::ForceReply.new(force_reply: true)
        bot.api.send_message(
          chat_id: message.chat.id,
          text: 'Type the name of the book you want to download',
          reply_markup: reply_markup
        )
      when /^\/[a-zA-Z0-9]+$/
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Sorry, I can't understand that command"
        )
      else
        begin
          books = Bot::Book.search(message.text)
          question = "Which of these books are you trying to download?\n\n"
          books.each do |book|
            question << "/#{book.id} - #{book.title}"
            question << " - #{book.sub_title}" if book.respond_to?(:sub_title)
            question << "\n"
          end
          bot.api.send_message(
            chat_id: message.chat.id,
            text: question,
            disable_web_page_preview: true,
            parse_mode: 'html'
          )
        rescue Exception => e
          bot.api.send_message(
            chat_id: message.chat.id,
            text: e.message
          )
        end
      end
      puts "Response to question #{message.text} sent to @#{message.chat.username}"
    end
  end
end
