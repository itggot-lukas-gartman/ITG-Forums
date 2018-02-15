class App < Sinatra::Base
	enable :sessions
	register Sinatra::Flash
	
	helpers do
		def display(file)
			slim file
		end
	end
	
	helpers Sinatra::Streaming
	
	db = SQLite3::Database.open('db/database.sqlite')
	$user = false
	$admin = false


	# not_found do
	# 	session[:url] = request.fullpath
	# 	redirect '/not_found'
	# end

	get '/not_found' do
		status 404
		@title = "ITG Forums | Not found"
		@url = session[:url]
		session[:url] = ""
		slim :'utils/not_found'
	end
	
	get '/denied' do
		status 403
		@title = "ITG Forums | Denied"
		slim :'utils/denied'
	end

	get '/' do
		@title = "ITG Forums | Home"
		
		@forums = db.execute("SELECT * FROM forums")
		@subforums = db.execute("SELECT * FROM subforums")
		@threadinfo = db.execute("SELECT id, subforum, title, owner, date FROM threads")
		# @postinfo = db.execute("SELECT * FROM posts GROUP BY subforum")
		
		# flash[:success] = "haha lol"
		slim :index
	end
	
	get '/register' do
		@title = "ITG Forums | Register"
		
		slim :register
	end
	
	post '/register' do
		username = params['username'].downcase
		password = params['password']
		email = params['email'].downcase
		encrypted_pass = BCrypt::Password.create(password)
		username_check = db.execute("SELECT username FROM accounts WHERE username = ?", username).first 
		email_check = db.execute("SELECT email FROM accounts WHERE email = ?", email).first
		
		if !username_check.nil?
			flash[:error] = "Username already exists"
			redirect back
		elsif !email_check.nil?
			flash[:error] = "Email is already in use"
			redirect back
		elsif !/^[a-zA-Z0-9_]\w{2,15}$/.match(username)
			flash[:error] = "Username may only contain characters (A-Z), numbers (0-9), underscores and be 3-16 characters long"
			redirect back
		elsif !/\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.match(email)
			flash[:error] = "Please enter a valid email address."
			redirect back
		elsif password.length < 6
			flash[:error] = "Password must be at least 6 characters long"
			redirect back
		else
			db.execute("INSERT INTO accounts (username, encrypted_pass, email) VALUES (?, ?, ?)", username, encrypted_pass, email)
			session[:username] = username
			session[:profile_picture] = "/uploads/profile-picture/default.svg"
			$user = session[:username]
			flash[:success] = "Account registered. Welcome to ITG forums!"
			redirect '/'
		end
	end
	
	post '/login' do
		username = params['username'].downcase
		password = params['password']
		credentials = db.execute("SELECT username, encrypted_pass, picture FROM accounts WHERE username = ?", username).first
		if credentials.nil?
			flash[:error] = "Invalid username or password"
			redirect back
		else
			encrypted_pass = BCrypt::Password.new(credentials[1])
			if (credentials.first.downcase == username.downcase) && (encrypted_pass == password)
				session[:username] = username
				$user = session[:username]
				session[:profile_picture] = credentials[2]
				redirect back
			else
				flash[:error] = "Invalid username or password"
				redirect back
			end
		end
	end
	
	get '/logout' do
		if session[:username]
			session.destroy
			$user = false
			$admin = false
			redirect '/'
		else
			flash[:error] = "You are not logged in"
			redirect back
		end
	end
	
	
	
	get '/settings' do
		if session[:username]
			# @username = session[:username]
			@email = db.execute("SELECT email FROM accounts WHERE username = ?", session[:username]).first.first
			slim :settings
		else
			redirect '/denied'
		end
	end
	
	post '/settings/email' do
		if session[:username]
			new_email = params['email']
			db.execute("UPDATE accounts SET email = ? WHERE username = ?", new_email, session[:username])
			flash[:success] = "Email updated"
			redirect back
		else
			redirect '/denied'
		end
	end
	
	post '/settings/password' do
		if session[:username]
			old_password = params['old_password']
			new_password = params['new_password']
			repeat_password = params['repeat_password']
			db_pass = db.execute("SELECT encrypted_pass FROM accounts WHERE username = ?", session[:username]).first.first
			encrypted_pass = BCrypt::Password.new(db_pass)
			if encrypted_pass == old_password
				if new_password.length < 6
					flash[:error] = "New password must be at least 6 characters long."
					redirect back
				else
					new_encrypted_pass = BCrypt::Password.create(new_password)
					db.execute("UPDATE accounts SET encrypted_pass = ? WHERE username = ?", new_encrypted_pass, session[:username])
					flash[:success] = "Password updated"
					redirect back
				end
			elsif new_password != repeat_password
				flash[:error] = "New passwords does not match"
				redirect back
			else
				flash[:error] = "Old password does not match"
				redirect back
			end
		else
			redirect '/denied'
		end
	end


	get '/subforum/:id' do
		id = params['id']
		begin
			@subforum = db.execute("SELECT name FROM subforums WHERE id = ?", id).first.first
		rescue
			session[:url] = request.fullpath
			redirect '/not_found'
		end
		@threads = db.execute("SELECT * FROM threads WHERE subforum = ?", id)
		@latest_posts = []
		for thread in @threads
			post = db.execute("SELECT thread, owner, date FROM posts WHERE thread = ?", thread[0]).last

			if post.nil?
				profile_picture = db.execute("SELECT picture FROM accounts WHERE username = ?", thread[3]).first.first
				post = [false, thread[0]]
				post.push(profile_picture)
				@latest_posts.push(post)
			else
				profile_picture = db.execute("SELECT picture FROM accounts WHERE username = ?", post[1]).first.first
				post.push(profile_picture)
				@latest_posts.push(post)
			end

			# unless post.nil?
			# 	profile_picture = db.execute("SELECT picture FROM accounts WHERE username = ?", post[1]).first.first
			# 	post.push(profile_picture)
			# 	@latest_posts.push(post)
			# end
		end
		p @latest_posts
		slim :subforum
	end

	get '/thread/:id' do
		id = params['id']
		@thread = db.execute("SELECT * FROM threads WHERE id = ?", id).first
		@posts = db.execute("SELECT * FROM posts WHERE thread = ?", id)
		slim :thread
	end

	
	get '/members' do
		@title = "ITG Forums | Members"
		@members = db.execute("SELECT username, rank FROM accounts")
		slim :members
	end
end