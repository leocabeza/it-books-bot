require './lib/reply_markup_formatter'
require './lib/app_configurator'

class MessageSender
  attr_reader :bot
  attr_reader :text
  attr_reader :chat
  attr_reader :answers
  attr_reader :reply_to_message_id
  attr_reader :parse_mode
  attr_reader :reply_markup
  attr_reader :disable_web_page_preview
  attr_reader :message
  attr_reader :logger

  def initialize(options)
    @bot = options[:bot]
    @text = options[:text]
    @chat = options[:chat]
    @answers = options[:answers]
    @reply_to_message_id = options[:reply_to_message_id]
    @parse_mode = options[:parse_mode]
    @reply_markup = options[:reply_markup] || ''
    @disable_web_page_preview = options[:disable_web_page_preview] || false
    @message = options[:message]
    @logger = AppConfigurator.new.get_logger
  end

  def send
    if answer_exists
      bot.api.send_message(
        chat_id: chat.id,
        text: text,
        reply_markup: answer_exists,
        disable_web_page_preview: disable_web_page_preview,
        parse_mode: parse_mode
      )
    elsif reply_markup
      bot.api.send_message(
        chat_id: chat.id,
        text: text,
        reply_markup: reply_markup,
        disable_web_page_preview: disable_web_page_preview,
        parse_mode: parse_mode
      )
    else
      bot.api.send_message(chat_id: chat.id, text: text)
    end

    logger.debug "sending answer to #{chat.username}"
  end

  def edit_callback
    bot.api.edit_message_text(
      chat_id: message.chat.id,
      message_id: message.message_id,
      text: text,
      disable_web_page_preview: true,
      reply_markup: reply_markup,
      parse_mode: parse_mode
    )
  end

  def send_chat_action
    bot.api.sendChatAction(
      chat_id: chat.id,
      action: 'typing'
    )

    logger.debug "sending chat action to #{chat.username}"
  end

  def send_reply
    bot.api.send_message(
      chat_id: chat.id,
      text: text,
      reply_to_message_id: reply_to_message_id,
      parse_mode: parse_mode
    )

    logger.debug "sending reply to #{chat.username}"
  end

  private

  def answer_exists
    if answers
      ReplyMarkupFormatter.new(answers).get_markup
    end
  end
end
