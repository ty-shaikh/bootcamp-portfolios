def get_client_data
  slug = params['account']
  project_slug = params['id']
  account = DB.current_account(param['account'])

  return account, recruiter, positions
end


get '/:account' do
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
  Portfolio.post_contact(@account.email, params['name'], params['email'], params['message'])
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
