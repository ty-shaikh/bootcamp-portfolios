def get_client_data
  slug = params['account']
  project_slug = params['id']
  account = DB.current_account(param['account'])

  return account, recruiter, positions
end
