class App

  def call(env)
    [200, {'Content-Type' => 'text/html'}, 'Hello, World']
  end
end
