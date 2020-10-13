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

  def self.current_published_projects(slug)
    items = []
    store = YAML::Store.new "./data/#{slug}/projects.store"

    store.transaction(true) do
      store.roots.each { |root| items.append(store[root]) if store[root].hidden == false }
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

  def self.current_domains
    items = []
    store = YAML::Store.new "./data/domains.store"

    store.transaction(true) do
      store.roots.each { |root| items.append(store[root].domain) }
    end

    return items
  end

  def self.current_hostnames
    items = []
    store = YAML::Store.new "./data/domains.store"

    store.transaction(true) do
      store.roots.each do |root|
        obj = store[root]
        items.append(obj)

        www_obj = obj.clone
        www_obj.domain = "www." + obj.domain
        items.append(www_obj)
       end
    end

    return items
  end

end
