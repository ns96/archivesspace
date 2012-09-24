require 'net/http'
require 'json'

class User < JSONModel(:user)

  def self.establish_session(session, backend_session, username)
    session[:session] = backend_session["session"]
    session[:permissions] = backend_session["permissions"]
    session[:user] = username
  end


  def self.login(username, password)
    uri = JSONModel(:user).uri_for(username)

    response = JSONModel::HTTP.post_form("#{uri}/login", :password => password)

    if response.code == '200'
      JSON.parse(response.body)
    else
      nil
    end
  end

end