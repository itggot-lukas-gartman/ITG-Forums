POSTS_PER_PAGE = 10

#Slim HTML formatting
Slim::Engine.set_options pretty: true, sort_attrs: false

Database.establish_connection("app/db/database.sqlite")
