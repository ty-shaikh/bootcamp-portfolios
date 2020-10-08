require 'mailgun-ruby'

class Mailer
  API_KEY = "key-0916b0e78ee39f94534d56475d32b015"

  def self.demo_request(name, email)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"})
    mb_obj.add_recipient :to, 'me@tyshaikh.com'

    mb_obj.subject "New Demo Request"
    mb_obj.body_html "<p>Name: #{name}</p> <p>Email: #{email}</p>"

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

  def self.support_request(name, email, question)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"})
    mb_obj.add_recipient :to, 'me@tyshaikh.com'

    mb_obj.subject "New Support Request"
    mb_obj.body_html "<p>Name: #{name}</p> <p>Email: #{email}</p> <p>Question: #{question}</p>"

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

  def self.new_signup(name, email)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"})
    mb_obj.add_recipient :to, 'me@tyshaikh.com'

    mb_obj.subject "New Signup"
    mb_obj.body_html "<p>Name: #{name}</p> <p>Email: #{email}</p>"

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

  def self.new_account(email)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from "support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"}
    mb_obj.add_recipient :to, email

    mb_obj.subject "Welcome to Hire Anchor!"
    mb_obj.body_html "<p>Thanks for creating an account with us!</p><p>You can login to your account, start adding team members and publishing open positions here: <a href='http://www.hireanchor.com/login' target='_blank'>dashboard link<a/>.</p> <p>If you have any questions or feedback, please reach out: support@hireanchor.com</p>"

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

  def self.new_applicant(recruiter_email, position_title, applicant_name, admin_url)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"})
    mb_obj.add_recipient :to, recruiter_email

    mb_obj.subject "New Applicant for #{position_title}"
    mb_obj.body_html "<p>You received a new applicant for the position: #{position_title}.</p> <p>The applicant's name is: #{applicant_name}.</p> <p><a href='#{admin_url}' target='_blank'>Click here to view the applicant's resume<a/>.</p>"

    time_delay = (Time.now + 5*60).to_s
    mb_obj.deliver_at time_delay

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

  def self.new_candidate(recruiter_email, candidate_name, admin_url)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"})
    mb_obj.add_recipient :to, recruiter_email

    mb_obj.subject "New Candidate from Resume Drop"
    mb_obj.body_html "<p>You received a new candidate from the resume drop form.</p> <p>The candiate's name is: #{candidate_name}.</p> <p><a href='#{admin_url}' target='_blank'>Click here to view the candidate's resume<a/>.</p>"

    time_delay = (Time.now + 5*60).to_s
    mb_obj.deliver_at time_delay

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

  def self.password_reset(email, password)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"})
    mb_obj.add_recipient :to, email

    mb_obj.subject "Password reset instructions"
    mb_obj.body_html "<p>You recently tried to reset your password.</p> <p>We have auto-generated one for your convenience: <strong>#{password}<strong></p> <p>If you did not request a new password, please reach out: support@hireanchor.com</p>"

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

  def self.new_employee(email, password)
    mg_client = Mailgun::Client.new API_KEY
    mb_obj = Mailgun::MessageBuilder.new()

    mb_obj.from("support@hireanchor.com", {"first" => "Hire", "last" => "Anchor"})
    mb_obj.add_recipient :to, email

    mb_obj.subject "New account details"
    mb_obj.body_html "<p>Your team lead has created an account for you with Hire Anchor.</p> <p>Your username is this email address and your password is <strong>#{password}</strong></p> <p>You can change this password on your profile page</p> <p><a href='https://www.hireanchor.com/login' target='_blank'>You can access your account now and start adding new positions!</a></p>"

    mg_client.send_message 'mg.hireanchor.com', mb_obj
  end

end
