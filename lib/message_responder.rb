require 'open-uri'
require './models/user'
require './lib/message_sender'
require './lib/it_ebook.rb'

class MessageResponder
  attr_reader :message
  attr_reader :bot
  attr_reader :user

  def initialize(options)
    @bot = options[:bot]
    @message = options[:message]
    @user = User.find_or_create_by(uid: message.from.id)
  end

  def respond
    case message.text
    when /^\/start/
      say_hello
    when /^\/help/
      show_help
    when /^\/[0-9]+$/
      answer_with_book
    when /^\/search/i
      answer_with_question
    when /^\//
      answer_with_unknown_command
    when /^[\w\W\s]+$/
      answer_with_books
    else
      say_dont_know
    end
  end

  def respond_callback
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
      answer_callback_with_action
      books = Bot::Book.search(query, actual_page)
      question = I18n.t(
        'showing_page',
        actual_page: actual_page,
        pages_allowed: pages_allowed
      )
      question << I18n.t('which_book')
      books.each do |book|
        question << "\n&#128214; <b>#{book.title}</b>"
        question << " - <i>#{book.sub_title}</i>" if book.respond_to?(:sub_title)
        question << I18n.t('get_book', book_id: book.id)
      end
      kb = [
        Telegram::Bot::Types::InlineKeyboardButton
          .new(
            text: I18n.t('load_more'),
            callback_data: "#{query}//#{books[0].page}//#{books[0].total}"
          )
      ]
      markup = Telegram::Bot::Types::InlineKeyboardMarkup
        .new(inline_keyboard: kb)
      answer_callback_with_more_books(
        question, markup, true, 'html'
      )
    rescue Bot::QueryNullError => e
      bot.api.send_message(
        chat_id: message.from.id,
        text: e.message
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
  end

  private

  def say_hello
    answer_with_message(
      I18n.t(
        'greeting_message',
        name: message.from.first_name
      )
    )
  end

  def say_dont_know
    answer_with_message(
      I18n.t(
        'dont_know',
        name: message.from.first_name
      )
    )
  end

  def show_help
    answer_with_message(I18n.t('help_message'))
  end

  def answer_with_book
    begin
      answer_with_action
      book = Bot::Book.find(message.text)
      info = Bot::Book.get_book_info(book)
      answer_with_reply(info, message.message_id , 'html')
    rescue Bot::NoBookFoundError => e
      answer_with_message(e.message)
    rescue Bot::BadConnectionError => e
      answer_with_message(e.message)
    end
  end

  def answer_with_question
    reply_markup =
      Telegram::Bot::Types::ForceReply
        .new(force_reply: true)
    answer_with_reply_markup(
      I18n.t('what_book'),
      reply_markup
    )
  end

  def answer_with_unknown_command
    answer_with_message(I18n.t('do_not_understand'))
  end

  def answer_with_books
    encoded_query = message.text
    encoded_query.gsub! '//', ''
    encoded_query = URI::encode(encoded_query)
    begin
      books = Bot::Book.search(encoded_query)
      question = "I found <b>#{books[0].total}</b> results\n"
      question << "Which of these books are you trying to download?\n"
      books.each do |book|
        question << "\n&#128214; <b>#{book.title}</b>"
        question << " - <i>#{book.sub_title}</i>" if book.respond_to?(:sub_title)
        question << "\n  Get: /#{book.id}"
      end
      kb = [
        Telegram::Bot::Types::InlineKeyboardButton
          .new(
            text: 'Load more',
            callback_data: "#{encoded_query}//" <<
              "#{books[0].page}//#{books[0].total}"
          )
      ]
      markup = Telegram::Bot::Types::InlineKeyboardMarkup
        .new(inline_keyboard: kb)
      answer_with_reply_markup(
        question, markup, true, 'html'
      )
    rescue Bot::QueryTooLongError => e
      answer_with_message(e.message)
    rescue Bot::QueryNullError => e
      answer_with_message(e.message)
    rescue Bot::NoBookFoundError => e
      answer_with_message(e.message)
    rescue Bot::BadConnectionError => e
      answer_with_message(e.message)
    end
  end

  def answer_with_reply(text, reply_to_message_id,
    parse_mode)
    MessageSender.new(
      bot: bot,
      chat: message.chat,
      text: text,
      reply_to_message_id: reply_to_message_id,
      parse_mode: parse_mode
    ).send_reply
  end  

  def answer_with_message(text)
    MessageSender
      .new(bot: bot, chat: message.chat, text: text).send
  end

  def answer_with_reply_markup(
    text, reply_markup, disable_web_page_preview = false,
    parse_mode = 'html')
      MessageSender.new(
        bot: bot,
        chat: message.chat,
        text: text,
        reply_markup: reply_markup,
        disable_web_page_preview: disable_web_page_preview,
        parse_mode: parse_mode
      ).send
  end

  def answer_with_action
    MessageSender
      .new(bot: bot, chat: message.chat).send_chat_action
  end

  def answer_callback_with_action
    MessageSender.new(
      bot: bot,
      chat: message.message.chat
    ).send_chat_action
  end

  def answer_callback_with_more_books(
    text, reply_markup, disable_web_page_preview, parse_mode
    )
    MessageSender.new(
      bot: bot,
      message: message.message,
      text: text,
      reply_markup: reply_markup,
      parse_mode: parse_mode
    ).edit_callback
  end
end
