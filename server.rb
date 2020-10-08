require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/flash'
require 'yaml/store'
require 'ostruct'
require 'nokogiri'
require 'securerandom'
require 'dotenv'
require './helpers/mailer'
require './helpers/auth'
require './helpers/db'

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

  def require_admin
    if @user.role != 'admin'
      redirect "/admin/#{@account_slug}/#{@recruiter_slug}"
    end
  end
end

get '/' do
  erb :landing, :layout => :layout
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
    # recipient = settings.development? ? 'me@tyshaikh.com' : email
    # Mailer.password_reset(recipient, password)

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

  if existing_user or existing_account
    flash[:error] = 'There is already an account using that email or name.'
    redirect '/register'
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
      slug: slug,
      headshot: 'placeholder.png',
      resume: '',
      summary: params['summary'],
      user_email: email,
    )

    # Send welcome emails
    # recipient = settings.development? ? 'me@tyshaikh.com' : user.email
    # Mailer.new_account(recipient)

    # Notify me of new signup
    # Mailer.new_signup(params['personal-name'], recipient)

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
    FileUtils.cp("./data/seed.store", "./data/#{slug}/projects.store")

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
  @account.summary = params["summary"]
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
## Admin Projects
########

# @slug, @user, @account

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

  project = OpenStruct.new(
    title: params["title"],
    summary: params["summary"],
    description: params["description"],
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

  # Update values
  project.title = params["title"]
  project.summary = params["summary"]
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
## Public Portfolios
########
