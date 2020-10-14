require 'yaml/store'
require "ostruct"

host_names = []

domains = YAML::Store.new "../data/domains.store"
accounts = YAML::Store.new "../data/accounts.store"

accounts.transaction(true) do
  accounts.roots.each do |root|
    account = accounts[root]

    slug = account.slug
    domain = account.host

    next if domain == ''

    domain_obj = OpenStruct.new(domain: domain, slug: slug)
    domains.transaction { domains[slug] = domain_obj }

  end
end
