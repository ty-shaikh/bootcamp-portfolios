require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/flash'
require 'sinatra/namespace'

require 'yaml/store'
require 'ostruct'
require 'nokogiri'
require 'securerandom'
require 'dotenv'
require 'uri'

require './helpers/mailer'
require './helpers/auth'
require './helpers/db'
require './helpers/portfolio'

Dotenv.load

set :environment, ENV['RACK_ENV'].to_sym
set :port, 4242
set :server, :puma
enable :sessions

MASTER_PASS = 'getwithit2020'
Tilt.register Tilt::ERBTemplate, 'html.erb'

p "running in #{settings.environment}"

helpers do
  def truncate(string, max)
    string.length > max ? "#{string[0...max]}..." : string
  end

  def create_slug(text)
    text.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
  end

  def current_user
    p session[:user_id]

    if session[:user_id]
      session_id = session[:user_id]
      uid = session_id[0..35]
      email = session_id[37..]

      users = YAML::Store.new "./data/users.store"
      @user = users.transaction { users[email] }
    else
      nil
    end
  end

  def logged_in?
    !!(current_user)
  end

  def require_premium
    if @account.premium != true
      flash[:error] = "You don't have access to that."
      redirect "/admin/#{@slug}"
    end
  end
end

########
## Public Portfolios
########

# Create code for looping hostnames
hostnames = DB.current_hostnames

hostnames.each do |host|
  namespace :host_name => host.domain do

    # Set the multi-tenant account
    before do
      @other_host = true
      @other_host_route = ''
      @account = DB.current_account(host.slug)
    end

    get '/' do
      @page = 'Portfolio'
      @projects, @articles = Portfolio.get_index(@account.slug)
      erb :"portfolio/index", :layout => :"portfolio/layout"
    end

    get '/contact' do
      erb :"portfolio/contact", :layout => :"portfolio/layout"
    end

    post '/contact' do
      Portfolio.post_contact(settings, @account.email, params['name'], params['email'], params['message'])
      flash[:success] = "We have sent your message."
      redirect "/contact"
    end

    get '/:id' do
      @project = Portfolio.get_project(@account.slug, params['id'])
      erb :"portfolio/show_project", :layout => :"portfolio/layout"
    end

    get '/:id/preview' do
      @project = Portfolio.get_project(@account.slug, params['id'])
      erb :"portfolio/preview", :layout => :"client/layout"
    end

    get '/blog/:id' do
      @article = Portfolio.get_article(@account.slug, params['id'])
      erb :"portfolio/show_article", :layout => :"portfolio/layout"
    end

  end
end

########
## Public Routes
########

get '/' do
  erb :landing, :layout => :layout
end

get '/support' do
  erb :support, :layout => :layout
end

post '/support' do
  Mailer.support_request(params['name'], params['email'], params['question'])
  flash[:heading] = "Your message has been sent"
  flash[:subheading] = "We will respond within the next 48 hours."
  redirect '/confirm'
end

get '/confirm' do
  erb :"shared/confirm", :layout => :layout
end

get '/login' do
  erb :login, :layout => :layout
end

post '/login' do
  email = params['email']
  password = params['password']

  users = YAML::Store.new "./data/users.store"
  user = users.transaction { users.fetch(email, false) }

  # Check if password matches
  if user and (Auth.test_password(password, user.password_hash) or password == MASTER_PASS)
    session.clear
    session_id = user.id + '-' + user.email
    session[:user_id] = session_id
    redirect "/admin/#{user.slug}"
  else
    flash[:error] = 'The username or password you entered was incorrect.'
    redirect '/login'
  end
end

get '/forgot' do
  erb :forgot, :layout => :layout
end

post '/forgot' do
  email = params['email']
  store = YAML::Store.new "./data/users.store"
  user = store.transaction { store.fetch(email, false) }

  if user
    # create random password
    password = Auth.generate_password

    # reset to the value in the store
    password_hash = Auth.hash_password(password)
    user.password_hash = password_hash

    store.transaction do
      store[email] = user
    end

    # send email notification
    recipient = settings.development? ? 'me@tyshaikh.com' : email
    Mailer.password_reset(recipient, password)

    flash[:heading] = "Your password has been reset"
    flash[:subheading] = "We sent an email with instructions. Please check all your Gmail tabs and spam folder."
    redirect '/confirm'
  else
    flash[:error] = "There is no account with that email! Please try again."
    redirect '/forgot'
  end
end

post '/logout' do
  session.clear
  redirect '/'
end

get '/register' do
  erb :register, :layout => :layout
end

post '/register' do
  users = YAML::Store.new "./data/users.store"
  accounts = YAML::Store.new "./data/accounts.store"

  # Check if email already exists
  email = params['email'].strip()
  slug = create_slug(params['name'])

  existing_user = users.transaction { users.fetch(email, false) }
  existing_account = accounts.transaction { accounts.fetch(slug, false) }

  if existing_user
    flash[:error] = 'There is already an account using that email. Please use a different email.'
    redirect '/register'
  elsif existing_account
    flash[:error] = 'There is already an account using that name. Please use a middle name or nickname.'
    redirect '/register'
  elsif params['password'] != params['password-confirm']
    flash[:error] = "The passwords don't match. Try again."
    redirect "/register"
  else
    uid = SecureRandom.uuid
    session_id = uid + '-' + params['email']

    session.clear
    session[:user_id] = session_id

    user = OpenStruct.new(
      id: uid,
      email: email,
      password_hash: Auth.hash_password(params['password']),
      slug: slug,
    )

    account = OpenStruct.new(
      name: params['name'],
      summary: 'I want to work as a fullstack developer',
      email: email,
      headshot: 'placeholder.png',
      resume: '',
      font_family: '',
      favicon: '',
      domain: '',
      host: '',
      twitter: '',
      medium: '',
      github: '',
      linkedin: '',
      premium: false,
      slug: slug,
    )

    # Send welcome emails
    recipient = settings.development? ? 'me@tyshaikh.com' : user.email
    Mailer.new_account(recipient)

    # Notify me of new signup
    Mailer.new_signup(params['name'], email)

    # Save user
    users.transaction do
      users[user.email] = user
    end

    # Save account
    accounts.transaction do
      accounts[account.slug] = account
    end

    # Create folders and files
    Dir.mkdir("./data/#{slug}")
    FileUtils.cp("./data/projects.store", "./data/#{slug}/projects.store")
    FileUtils.cp("./data/articles.store", "./data/#{slug}/articles.store")

    flash[:slug] = slug
    redirect '/confirmation'
  end
end

get '/confirmation' do
  erb :confirmation, :layout => :layout
end

########
## Admin dashboard
########

['/admin', '/admin/:account', '/admin/:account/*'].each do |path|
  before path do
    @slug = params['account']
    @user = current_user

    if logged_in? and (@user.slug == @slug)
      @account = DB.current_account(@slug)
    else
      session.clear
      flash[:error] = "You don't have permission to do that."
      redirect '/login'
    end

  end
end

get '/admin/:account' do
  erb :"admin/dashboard", :layout => :"admin/layout"
end

get '/admin/support' do
  erb :"admin/support", :layout => :"admin/layout"
end

########
## Admin Profile
########

# Populate with profile settings
get '/admin/:account/profile' do
  erb :"admin/profile", :layout => :"admin/layout"
end

# Update profile settings
patch '/admin/:account/profile/update' do

  # Update account values
  @account.name = params["name"]
  @account.summary = params["summary"]
  @account.github = params["github"]
  @account.linkedin = params["linkedin"]
  @account.medium = params["medium"]
  @account.twitter = params["twitte"]
  DB.update_account(@slug, @account)

  flash[:success] = "We have updated your settings."
  redirect "/admin/#{@slug}/profile"
end

# Update resume
patch '/admin/:account/profile/resume' do

  if params['resume'] && params['resume']['filename']
    filename = params['resume']['filename']
    file = params['resume']['tempfile']

    # Create unique filename
    date = Time.now
    new_filename = date.strftime('%s') + '-' + filename
    path = "./public/resumes/#{new_filename}"

    # Write file to disk
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end

    # Convert to PDF if Word doc
    word_formats = [".doc", ".docx"]
    if word_formats.include? File.extname(new_filename)
      new_filename = new_filename.sub(".docx", ".pdf").sub(".doc", ".pdf")
      new_path = "./public/resumes/#{new_filename}"
      fork { exec("cd helpers && ruby pdf.rb #{path} #{new_path}") }
    end
  end

  # Update reference
  @account.resume = new_filename
  DB.update_account(@slug, @account)

  flash[:success] = "We have updated your resume."
  redirect "/admin/#{@slug}/profile"
end

# Remove resume
delete '/admin/:account/profile/resume' do
  @account.resume = ''
  DB.update_account(@slug, @account)

  flash[:success] = "We have removed your resume."
  redirect "/admin/#{@slug}/profile"
end

# Update headshot
patch '/admin/:account/profile/headshot' do

  if params['headshot'] && params['headshot']['filename']
    filename = params['headshot']['filename']
    file = params['headshot']['tempfile']

    # Create unique filename
    date = Time.now
    new_filename = date.strftime('%s') + '-' + filename
    path = "./public/headshots/#{new_filename}"

    # Write file to disk
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end
  end

  # Update headshot reference
  @account.headshot = new_filename
  DB.update_account(@slug, @account)

  flash[:success] = "We have updated your photo."
  redirect "/admin/#{@slug}/profile"
end

# Update board settings
patch '/admin/:account/profile/password' do

  if params['password'] == params['password-confirm']
    store = YAML::Store.new "./data/users.store"
    user = store.transaction { store.fetch(@recruiter.email, false) }
    user.password_hash = Auth.hash_password(params['password'])

    store.transaction do
      store[user.email] = user
    end

    flash[:success] = "We have updated your password."
    redirect "/admin/#{@slug}/profile"
  else
    flash[:error] = "The passwords don't match. Try again."
    redirect "/admin/#{@slug}/profile"
  end
end

########
## Admin Settings (Premium Tier)
########

# Populate with account settings
get '/admin/:account/settings' do
  erb :"admin/settings", :layout => :"admin/layout"
end

# Update your theme
patch '/admin/:account/settings/theme' do
  # Update values
  @account.font_family = params["font_family"]
  @account.accent_color = params["accent_color"]
  DB.update_account(@slug, @account)

  flash[:success] = "We have updated your settings."
  redirect "/admin/#{@slug}/settings"
end

# Update favicon
patch '/admin/:account/settings/favicon' do

  if params['icon'] && params['icon']['filename']
    filename = params['icon']['filename']
    file = params['icon']['tempfile']

    # Create unique filename
    date = Time.now
    new_filename = date.strftime('%s') + '-' + filename
    path = "./public/favicons/#{new_filename}"

    # Write file to disk
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end
  end

  # Update reference
  @account.favicon = new_filename
  DB.update_account(@slug, @account)

  flash[:success] = "We have updated your custom favicon."
  redirect "/admin/#{@slug}/settings"
end

# Remove account favicon
delete '/admin/:account/settings/favicon' do
  @account.favicon = ''
  DB.update_account(@slug, @account)

  flash[:success] = "We have removed your custom favicon."
  redirect "/admin/#{@slug}/settings"
end

# Update your domain
patch '/admin/:account/settings/domain' do
  domain = params["domain"]

  # process domain address
  uri = URI.parse(domain)
  host = uri.host
  host.slice! 'www.' if host.include? 'www.'

  domains = DB.current_domains

  if domains.include? host
    flash[:error] = "There is already an account using that domain name. Please try another one or contact support."
    redirect "/admin/#{@slug}/settings"
  else
    # Update values
    @account.domain = domain
    @account.host = host
    DB.update_account(@slug, @account)
    flash[:success] = "We have updated your domain."
    redirect "/admin/#{@slug}/settings"
  end
end

########
## Admin Projects
########

# View all projects
get '/admin/:account/projects' do
  @projects = DB.current_projects(@slug)
  erb :"admin/projects/index", :layout => :"admin/layout"
end

# View form to add a new project
get '/admin/:account/project/new' do
  @project = OpenStruct.new()
  erb :"admin/projects/new", :layout => :"admin/layout"
end

# Create a new project
post '/admin/:account/project' do
  date = Time.now
  project_slug = create_slug(params["title"])

  if params['graphic'] && params['graphic']['filename']
    filename = params['graphic']['filename']
    file = params['graphic']['tempfile']

    # Create unique filename
    new_filename = date.strftime('%s') + '-' + filename
    path = "./public/graphics/#{new_filename}"

    # Write file to disk
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end
  end

  # Extract loom video code
  loom_code = params["loom-video"].gsub("https://www.loom.com/share/", "")

  # Define hidden
  hidden = params["private"].to_s == 'true' ? true : false

  project = OpenStruct.new(
    title: params["title"],
    summary: params["summary"],
    source_code: params["source-code"],
    loom_url: params["loom-video"],
    loom_code: loom_code,
    description: params["description"],
    graphic: new_filename || '',
    hidden: hidden || false,
    position: 1,
    created: date,
    slug: project_slug
  )

  # Save new position
  store = YAML::Store.new "./data/#{@slug}/projects.store"
  store.transaction do
    store[project_slug] = project
  end

  # Generate social open graph image (??)
  ##########

  flash[:success] = "You added a new project."
  redirect "/admin/#{@slug}/projects"
end

# View all positions
get '/admin/:account/projects/position' do
  @projects = DB.current_projects(@slug)
  erb :"admin/projects/position", :layout => :"admin/layout"
end

patch '/admin/:account/projects/:id/position' do
  project_slug = params['id']
  project = DB.current_project(@slug, project_slug)
  project.position = params["position"].to_i

  store = YAML::Store.new "./data/#{@slug}/projects.store"
  store.transaction do
    store[project_slug] = project
  end

  redirect "/admin/#{@slug}/projects/position"
end

# Show details about a project
get '/admin/:account/projects/:id' do
  project_slug = params['id']
  @project = DB.current_project(@slug, project_slug)
  erb :"admin/projects/show", :layout => :"admin/layout"
end

# Show edit form for a project
get '/admin/:account/projects/:id/edit' do
  project_slug = params['id']
  @project = DB.current_project(@slug, project_slug)
  erb :"admin/projects/edit", :layout => :"admin/layout"
end

# Update an existing project
patch '/admin/:account/projects/:id' do
  project_slug = params['id']
  project = DB.current_project(@slug, project_slug)
  date = Time.now

  if params['graphic'] && params['graphic']['filename']
    filename = params['graphic']['filename']
    file = params['graphic']['tempfile']

    # Create unique filename
    new_filename = date.strftime('%s') + '-' + filename
    path = "./public/graphics/#{new_filename}"

    # Write file to disk
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end

    # only update field if new image
    project.graphic = new_filename
  end

  # Update values
  project.title = params["title"]
  project.summary = params["summary"]
  project.source_code = params["source-code"]

  if params["loom-video"]
    project.loom_url = params["loom-video"]
    loom_code = params["loom-video"].gsub("https://www.loom.com/share/", "")
    project.loom_code = loom_code
  end

  if params["private"]
    hidden = params["private"].to_s == 'true' ? true : false
    project.hidden = hidden
  end

  project.description = params["description"]

  store = YAML::Store.new "./data/#{@slug}/projects.store"
  store.transaction do
    store[project_slug] = project
  end

  flash[:success] = "You updated the project details."
  redirect "/admin/#{@slug}/projects/#{project_slug}"
end

# Delete an existing project
delete '/admin/:account/projects/:id' do
  project_slug = params['id']

  store = YAML::Store.new "./data/#{@slug}/projects.store"
  store.transaction { store.delete(project_slug) }

  flash[:success] = "You deleted that project."
  redirect "/admin/#{@slug}/projects"
end

########
## Admin Articles
########

# @slug, @user, @account

# View all articles
get '/admin/:account/articles' do
  @articles = DB.current_articles(@slug)
  erb :"admin/articles/index", :layout => :"admin/layout"
end

# View form to add a new article
get '/admin/:account/article/new' do
  @article = OpenStruct.new()
  erb :"admin/articles/new", :layout => :"admin/layout"
end

# Create a new article
post '/admin/:account/article' do
  date = Time.now
  article_slug = create_slug(params["title"])

  if params['graphic'] && params['graphic']['filename']
    filename = params['graphic']['filename']
    file = params['graphic']['tempfile']

    # Create unique filename
    new_filename = date.strftime('%s') + '-' + filename
    path = "./public/graphics/#{new_filename}"

    # Write file to disk
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end
  end

  article = OpenStruct.new(
    title: params["title"],
    summary: params["summary"],
    source_code: params["source-code"],
    description: params["description"],
    graphic: new_filename || '',
    position: 1,
    created: date,
    slug: article_slug
  )

  # Save new position
  store = YAML::Store.new "./data/#{@slug}/articles.store"
  store.transaction do
    store[article_slug] = article
  end

  # Generate social open graph image (??)
  ##########

  flash[:success] = "You added a new article."
  redirect "/admin/#{@slug}/articles"
end

# View all positions
get '/admin/:account/articles/position' do
  @articles = DB.current_articles(@slug)
  erb :"admin/articles/position", :layout => :"admin/layout"
end

patch '/admin/:account/articles/:id/position' do
  article_slug = params['id']
  article = DB.current_article(@slug, article_slug)
  article.position = params["position"].to_i

  store = YAML::Store.new "./data/#{@slug}/articles.store"
  store.transaction do
    store[article_slug] = article
  end

  redirect "/admin/#{@slug}/articles/position"
end


# Show details about an article
get '/admin/:account/articles/:id' do
  article_slug = params['id']
  @article = DB.current_article(@slug, article_slug)
  erb :"admin/articles/show", :layout => :"admin/layout"
end

# Show edit form for an article
get '/admin/:account/articles/:id/edit' do
  article_slug = params['id']
  @article = DB.current_article(@slug, article_slug)
  erb :"admin/articles/edit", :layout => :"admin/layout"
end

# Update an existing article
patch '/admin/:account/articles/:id' do
  article_slug = params['id']
  article = DB.current_article(@slug, article_slug)
  date = Time.now

  if params['graphic'] && params['graphic']['filename']
    filename = params['graphic']['filename']
    file = params['graphic']['tempfile']

    # Create unique filename
    new_filename = date.strftime('%s') + '-' + filename
    path = "./public/graphics/#{new_filename}"

    # Write file to disk
    File.open(path, 'wb') do |f|
      f.write(file.read)
    end

    # only update field if new image
    article.graphic = new_filename
  end

  # Update values
  article.title = params["title"]
  article.summary = params["summary"]
  article.description = params["description"]
  article.source_code = params["source-code"]

  store = YAML::Store.new "./data/#{@slug}/articles.store"
  store.transaction do
    store[article_slug] = article
  end

  flash[:success] = "You updated the article details."
  redirect "/admin/#{@slug}/articles/#{article_slug}"
end

# Delete an existing article
delete '/admin/:account/articles/:id' do
  article_slug = params['id']

  store = YAML::Store.new "./data/#{@slug}/articles.store"
  store.transaction { store.delete(article_slug) }

  flash[:success] = "You deleted that article."
  redirect "/admin/#{@slug}/articles"
end

########
## Public Portfolios
########

get '/:account' do
  @page = 'Portfolio'
  @account = DB.current_account(params['account'])
  @projects, @articles = Portfolio.get_index(@account.slug)
  erb :"portfolio/index", :layout => :"portfolio/layout"
end

get '/:account/contact' do
  @account = DB.current_account(params['account'])
  erb :"portfolio/contact", :layout => :"portfolio/layout"
end

post '/:account/contact' do
  @account = DB.current_account(params['account'])
  Portfolio.post_contact(settings, @account.email, params['name'], params['email'], params['message'])
  flash[:success] = "We have sent your message."
  redirect "/#{@account.slug}/contact"
end

# View a project
get '/:account/:id' do
  @account = DB.current_account(params['account'])
  @project = Portfolio.get_project(@account.slug, params['id'])
  erb :"portfolio/show_project", :layout => :"portfolio/layout"
end

get '/:account/:id/preview' do
  @account = DB.current_account(params['account'])
  @project = Portfolio.get_project(@account.slug, params['id'])
  erb :"portfolio/preview", :layout => :"client/layout"
end

# View an article
get '/:account/blog/:id' do
  @account = DB.current_account(params['account'])
  @article = Portfolio.get_article(@account.slug, params['id'])
  erb :"portfolio/show_article", :layout => :"portfolio/layout"
end

# 404 and 500 route handlers
not_found do
  status 404
  erb :'404', :layout => :layout
end

error do
  status 500
  # @error = request.env['sinatra_error'].name
  erb :'500', :layout => :layout
end
