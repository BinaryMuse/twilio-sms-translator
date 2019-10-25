require "faraday"
require "twilio-ruby"

# Since we don't actually save our Message to
# the database, it doesn't need to be an
# ActiveRecord model (because ActiveRecord
# provides all the database abstractions).
# It can be a plain Ruby object instead.
class Message
  # Every time we create a new Message instance,
  # we want it to remember what the message's
  # recipient, langauge, and content are, so that
  # we can refer to them later. Since
  # `to` is a preposition and `recipient` is a
  # noun, we'll use that varaible name.
  # And since `language` is ambiguous
  # (source language or target language?)
  # we'll specify that too.
  def initialize(recipient, target_language, content)
    # Here we use instance variables because we
    # want to keep track of a Message's language
    # and content across the entire instance,
    # including all it's methods.
    @recipient = recipient
    @target_language = target_language
    @content = content
  end

  # get_translation returns the translation for the
  # Message's content based on it's language.
  # Note that the Message's content isn't updated;
  # a whole new string is returned.

  def get_translation
    # Even though we're defining a whole new method,
    # we want it to have access to the same language
    # and content as when its instance was created
    # (so we again use the instance variables).
    resp = Faraday.get 'https://translate.yandex.net/api/v1.5/tr.json/translate' do |req|
      req.params['lang'] = "en-#{@target_language}" # this is easier to reason about w/ the new variable name
      req.params['key'] = ENV['YANDEX_API_KEY']
      req.params['text'] = @content
    end

    # This is basically the same, but I think that
    # "do a thing unless some other thing" reads
    # pretty naturally and is easier than a whole
    # if/else block.
    #
    # `resp.success?` just checks to see if the status
    # is 200, so if it's not, let's include the status we
    # got instead in the error message.
    raise RuntimeError, "Unexpected Yandex response code: #{resp.status}" unless resp.success?
    data = JSON.parse(resp.body)
    # Note that we no longer call `send` here.
    # The purpose of this method, per it's name,
    # is to get the translation for the Message object
    # the method was called on.
    data["text"][0]
  end

  # In this case, when we call `send`, we're telling it to
  # do a thing that has a side effect (in this case, send a translated
  # text message). Sometimes Rubyists name a method like this
  # with a bang, to make sure you know you're actually gonna do
  # something with this method instead of just return new data.
  def send!
    # But instead of passing `to` and `translated` as arguments
    # like we used to, we can just access data and methods on
    # the instance, thus removing duplication of data.
    translated = self.get_translation()

    client = Twilio::REST::Client.new(
      ENV['TWILIO_ACCOUNT_SID'],
      ENV['TWILIO_AUTH_TOKEN'])

    client.messages.create(
      from: ENV['TWILIO_PHONE_NUMBER'],
      to: @recipient, # the recipient is stored on the instance
      body: translated
    )
  end
end
