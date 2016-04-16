require 'telegram/bot'
require 'open-uri'
require './lib/bot/it_ebook.rb'

token = YAML::load(IO.read('config/secrets.yml'))['telegram_token']

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message
    when Telegram::Bot::Types::CallbackQuery
      results_per_page = 10
      query = message.data.split('//')[0]
      api_page = message.data.split('//')[1].to_i
      total_pages = message.data.split('//')[2].to_i
      pages_allowed = (total_pages / results_per_page).ceil + 1

      if (api_page == 1)
        actual_page = 2
      else
        actual_page = (pages_allowed / (total_pages.to_f / api_page.to_f)).ceil + 1
        if (actual_page > pages_allowed)
          actual_page = 1
        end
      end

      begin
        books = Bot::Book.search(query, actual_page)
        question = "Showing page <b>#{actual_page}</b> of #{pages_allowed}\n"
        question << "Which of these books are you trying to download?\n\n"
        books.each do |book|
          question << "/#{book.id} - <b>#{book.title}</b>"
          question << " - #{book.sub_title}" if book.respond_to?(:sub_title)
          question << "\n"
        end
        kb = [
          Telegram::Bot::Types::InlineKeyboardButton
            .new(
              text: 'Load more',
              callback_data: "#{query}//#{books[0].page}//#{books[0].total}"
            )
        ]
        markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
        bot.api.edit_message_text(
          chat_id: message.message.chat.id,
          message_id: message.message.message_id,
          text: question,
          disable_web_page_preview: true,
          reply_markup: markup,
          parse_mode: 'html'
        )
      rescue Bot::QueryTooLongError => e
        bot.api.send_message(
          chat_id: message.from.id,
          text: e.message
        )
      rescue Bot::NoBookFoundError => e
        bot.api.send_message(
          chat_id: message.from.id,
          text: e.message
        )
      rescue Bot::BadConnectionError => e
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
            "use the /search command"
        )
      when '/help'
        bot.api.send_message(
          chat_id: message.chat.id,
          text: 'Available commands: /search'
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
      when /^\/search/i
        reply_markup = Telegram::Bot::Types::ForceReply.new(force_reply: true)
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "What's the book name?",
          reply_markup: reply_markup
        )
      when /^\/[a-zA-Z0-9]+$/
        bot.api.send_message(
          chat_id: message.chat.id,
          text: "Sorry, I can't understand that command"
        )
      when /^[\w\W\s]+$/
        encoded_query = message.text
        encoded_query.gsub! '//', ''
        encoded_query = URI::encode(encoded_query)
        begin
          books = Bot::Book.search(encoded_query)
          question = "I found <b>#{books[0].total}</b> results\n"
          question << "Which of these books are you trying to download?\n\n"
          books.each do |book|
            question << "/#{book.id} - <b>#{book.title}</b>"
            question << " - #{book.sub_title}" if book.respond_to?(:sub_title)
            question << "\n"
          end
          kb = [
            Telegram::Bot::Types::InlineKeyboardButton
              .new(
                text: 'Load more',
                callback_data: "#{encoded_query}//#{books[0].page}//#{books[0].total}"
              )
          ]
          markup = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
          bot.api.send_message(
            chat_id: message.chat.id,
            text: question,
            disable_web_page_preview: true,
            parse_mode: 'html',
            reply_markup: markup
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
end
