require 'yaml/store'
require 'ostruct'

class DB

  def self.current_account(slug)
    store = YAML::Store.new "./data/accounts.store"
    item = store.transaction { store.fetch(slug, false) }
    return item
  end

  def self.update_account(slug, account)
    store = YAML::Store.new "./data/accounts.store"
    store.transaction { store[slug] = account }
  end

  def self.current_project(slug, item_slug)
    store = YAML::Store.new "./data/#{slug}/projects.store"
    item = store.transaction { store[item_slug] }
    return item
  end

  def self.current_projects(slug)
    items = []
    store = YAML::Store.new "./data/#{slug}/projects.store"

    store.transaction(true) do
      store.roots.each { |root| items.append(store[root]) }
    end

    return items.reverse
  end

  def self.current_article(slug, item_slug)
    store = YAML::Store.new "./data/#{slug}/articles.store"
    item = store.transaction { store[item_slug] }
    return item
  end

  def self.current_articles(slug)
    items = []
    store = YAML::Store.new "./data/#{slug}/articles.store"

    store.transaction(true) do
      store.roots.each { |root| items.append(store[root]) }
    end

    return items.reverse
  end

end
