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
