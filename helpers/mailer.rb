require 'mailgun-ruby'

class Mailer
  API_KEY = "key-0916b0e78ee39f94534d56475d32b015"

  def self.new_account(email)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from "support@classfol.io", {"first" => "Class", "last" => "Folio"}
    mb_obj.add_recipient :to, email

    mb_obj.subject "Welcome to Class Folio!"
    mb_obj.body_html "<p>Thanks for creating an account with us!</p><p>You can login to your account, start adding projects here: <a href='http://www.classfol.io/login' target='_blank'>dashboard link<a/>.</p> <p>If you have any questions or feedback, please reach out: support@classfol.io</p>"

    mg_client.send_message 'mg.classfol.io', mb_obj
  end

  def self.new_signup(name)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@classfol.io", {"first" => "Class", "last" => "Folio"})
    mb_obj.add_recipient :to, 'me@tyshaikh.com'

    mb_obj.subject "New Signup"
    mb_obj.body_html "<p>Name: #{name}</p> <p>Email: #{email}</p>"

    mg_client.send_message 'mg.classfol.io', mb_obj
  end

  def self.password_reset(email, password)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@classfol.io", {"first" => "Class", "last" => "Folio"})
    mb_obj.add_recipient :to, email

    mb_obj.subject "Password reset instructions"
    mb_obj.body_html "<p>You recently tried to reset your password.</p> <p>We have auto-generated one for your convenience: <strong>#{password}<strong></p> <p>If you did not request a new password, please reach out: support@class.fol.io</p>"

    mg_client.send_message 'mg.classfol.io', mb_obj
  end


  def self.contact_request(user_email, contact_name, contact_email, contact_message)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@classfol.io", {"first" => "Class", "last" => "Folio"})
    mb_obj.add_recipient :to, user_email

    mb_obj.subject "New Message"
    mb_obj.body_html "<p>You have recieved a new message from #{contact_name} (#{contact_email})</p><p>#{contact_message}</p>"

    mg_client.send_message 'mg.classfol.io', mb_obj
  end


  def self.support_request(name, email, question)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@classfol.io", {"first" => "Class", "last" => "Folio"})
    mb_obj.add_recipient :to, 'me@tyshaikh.com'

    mb_obj.subject "New Support Request"
    mb_obj.body_html "<p>Name: #{name}</p> <p>Email: #{email}</p> <p>Question: #{question}</p>"

    time_delay = (Time.now + 5*60).to_s
    mb_obj.deliver_at time_delay

    mg_client.send_message 'mg.classfol.io', mb_obj
  end

end
