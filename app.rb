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
	# $user = false
	# $mod = false
	# $admin = false

	before do
		if session[:username]
			@user = session[:username]
			p session[:username]
			rank = db.execute("SELECT rank FROM accounts WHERE username = ?", session[:username]).first.first
			p rank
			if rank == 3
				@admin = true
			elsif rank == 2
				@mod = true
			end
		else
			@user = false
			@mod = false
			@admin = false
		end
	end

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
		@denied = session[:denied]
		session[:denied] = ""
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
			# @user = session[:username]
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
				# @user = session[:username]
				session[:profile_picture] = credentials[2]
				# rank = db.execute("SELECT rank FROM accounts WHERE username = ?", username).first.first
				# if rank == 3
				# 	@admin = true
				# elsif rank == 2
				# 	@mod = true
				# end
				redirect back
			else
				flash[:error] = "Invalid username or password"
				redirect back
			end
		end
	end
	
	get '/logout' do
		if session[:username]
			session.delete(:username)
			# @user = false
			# @mod = false
			# @admin = false
			redirect '/'
		else
			flash[:error] = "You are not logged in"
			redirect back
		end
	end
	
	
	# Account settings
	get '/settings' do
		if session[:username]
			# @username = session[:username]
			@email = db.execute("SELECT email FROM accounts WHERE username = ?", session[:username]).first.first
			slim :settings
		else
			session[:denied] = "You are not logged in."
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
			session[:denied] = "You are not logged in."
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
			session[:denied] = "You are not logged in."
			redirect '/denied'
		end
	end

	# Account profile
	get '/profile/:username' do
		username = params[:username]
		begin
			@account = db.execute("SELECT * FROM accounts WHERE username = ?", username).first
		rescue
			session[:url] = request.fullpath
			redirect '/not_found'
		end
	end

	
	get '/subforum/:id/new' do
		id = params['id']
		forum = db.execute("SELECT forum FROM subforums WHERE id = ?", id).first.first
		permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum).first.first

		if @admin
			unless permission <= 3
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end



			slim :new_thread
		elsif @mod
			unless permission <= 2
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
			slim :new_thread
		elsif @user
			unless permission <= 1
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
			slim :new_thread
		else
			flash[:error] = "You must be logged in to create a new thread."
			redirect back
		end
	end

	get '/subforum/:id' do
		id = params['id']
		user_rank = db.execute("SELECT rank FROM accounts WHERE username = ?", session[:username]).first
		if user_rank.nil?
			user_rank = 0
		else
			user_rank = user_rank.first
		end

		forum_id = db.execute("SELECT forum FROM subforums WHERE id = ?", id).first.first
		forum_permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum_id).first.first
		if user_rank >= forum_permission
			begin
				@subforum = db.execute("SELECT id, name FROM subforums WHERE id = ?", id).first
				@title = "ITG Forums | #{@subforum[1]}"
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
			end
			slim :subforum
		else
			session[:denied] = "You don't have permission to view this forum."
			redirect '/denied'
		end
	end

	get '/subforum/:id/new' do
		id = params['id']

		user_rank = db.execute("SELECT rank FROM accounts WHERE username = ?", session[:username]).first
		if user_rank.nil?
			user_rank = 0
		else
			user_rank = user_rank.first
		end

		forum_id = db.execute("SELECT forum FROM subforums WHERE id = ?", id).first.first
		forum_permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum_id).first.first
		if user_rank >= forum_permission
			begin
				
			rescue

			end
		else
			session[:denied] = "You don't have permission to view this forum."
			redirect '/denied'
		end
	end

	get '/thread/:id' do
		id = params['id']

		user_rank = db.execute("SELECT rank FROM accounts WHERE username = ?", session[:username]).first
		if user_rank.nil?
			user_rank = 0
		else
			user_rank = user_rank.first
		end

		begin
			subforum_id = db.execute("SELECT subforum FROM threads WHERE id = ?", id).first.first
			forum_id = db.execute("SELECT forum FROM subforums WHERE id = ?", subforum_id).first.first
			forum_permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum_id).first.first

			if user_rank >= forum_permission
				@thread = db.execute("SELECT * FROM threads WHERE id = ?", id).first
				@title = "ITG Forums | #{@thread[1]}"
				@posts = db.execute("SELECT * FROM posts WHERE thread = ?", id)
				
				@thread_owner = db.execute("SELECT * FROM accounts WHERE username = ?", @thread[3]).first
				thread_count = db.execute("SELECT COUNT(owner) FROM threads WHERE owner = ?", @thread_owner[1]).first.first
				post_count = db.execute("SELECT COUNT(owner) FROM posts WHERE owner = ?", @thread_owner[1]).first.first
				total_post_count = thread_count + post_count
				@thread_owner.push(total_post_count)

				@post_owners = []
				for post in @posts
					owner = db.execute("SELECT * FROM accounts WHERE username = ?", post[3]).first
					thread_count = db.execute("SELECT COUNT(owner) FROM threads WHERE owner = ?", post[3]).first.first
					post_count = db.execute("SELECT COUNT(owner) FROM posts WHERE owner = ?", post[3]).first.first
					total_post_count = thread_count + post_count
					owner.push(total_post_count)
					@post_owners.push(owner)
				end
				slim :thread
			else
				session[:denied] = "You don't have permission to view this forum."
				redirect '/denied'
			end
		rescue
			session[:url] = request.fullpath
			redirect '/not_found'
		end
	end

	post '/thread/reply' do
		if session[:username]
			id = params['id']
			message = params['message']
			session[:reply_msg] = message

			begin
				user_rank = db.execute("SELECT rank FROM accounts WHERE username = ?", session[:username]).first.first
				subforum_id = db.execute("SELECT subforum FROM threads WHERE id = ?", id).first.first
				forum_id = db.execute("SELECT forum FROM subforums WHERE id = ?", subforum_id).first.first
				forum_permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum_id).first.first
				if user_rank >= forum_permission
					if message.length < 10
						flash[:error] = "Message is too short. Please do not post unnecessary spam messages that does not contribute to anything."
						redirect back
					elsif message.length > 10000
						flash[:error] = "Message exceeds 10000 characters."
						redirect back
					else
						db.execute("INSERT INTO posts (thread, text, owner) VALUES (?, ?, ?)", id, message, session[:username])
						flash[:success] = "Posted successfully!"
						session.delete(:reply_msg)
						redirect back
					end
				else
					session[:denied] = "You don't have permission to post in this forum."
					redirect '/denied'
				end
			rescue
				# session[:url] = request.fullpath
				redirect '/not_found'
			end
		else
			session[:denied] = "You must login before making a post."
			redirect '/denied'
		end
	end

	get '/activity' do
		# @posts = db.execute("")
		"Not implemented yet"
	end

	get '/users' do
		@title = "ITG Forums | Users"
		accounts = db.execute("SELECT * FROM accounts")

		@admins = []
		@mods = []
		@users = []
		
		for account in accounts
			if account[4] == 3
				@admins.push(account)
			elsif account[4] == 2
				@mods.push(account)
			else
				@users.push(account)
			end
		end

		slim :users
	end
end