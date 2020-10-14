def get_client_data
  slug = params['account']
  project_slug = params['id']
  account = DB.current_account(param['account'])

  return account, recruiter, positions
end


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
      @projects = DB.current_published_projects(@account.slug)
      @articles = DB.current_articles(@account.slug)
      erb :"portfolio/index", :layout => :"portfolio/layout"
    end

    get '/contact' do
      erb :"portfolio/contact", :layout => :"portfolio/layout"
    end

    post '/contact' do
      recipient = settings.development? ? 'me@tyshaikh.com' : @account.email
      Mailer.contact_request(recipient, params['name'], params['email'], params['message'])

      flash[:success] = "We have sent your message."
      redirect "/#{@account.slug}/contact"
    end

    get '/:id' do
      @project = DB.current_project(@account.slug, params['id'])
      erb :"portfolio/show_project", :layout => :"portfolio/layout"
    end

    get '/:id/preview' do
      @project = DB.current_project(@account.slug, params['id'])
      erb :"portfolio/preview", :layout => :"client/layout"
    end

    get '/blog/:id' do
      @article = DB.current_article(@account.slug, params['id'])
      erb :"portfolio/show_article", :layout => :"portfolio/layout"
    end

  end
end
