require './helpers/db'
require './helpers/mailer'

class Portfolio

  def self.get_index(account_slug)
    projects = DB.current_published_projects(account_slug)
    articles = DB.current_articles(account_slug)
    return projects, articles
  end

  def self.post_contact(settings, account_email, name, email, message)
    recipient = settings.development? ? 'me@tyshaikh.com' : account_email
    Mailer.contact_request(recipient, name, email, message)

  end

  def self.get_project(account_slug, project_id)
    project = DB.current_project(account_slug, project_id)
    return project
  end

  def self.get_article(account_slug, article_id)
    article = DB.current_article(account_slug, article_id)
    return article
  end

end
