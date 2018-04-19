class String
	def blank?
		self =~ /^\s*$/
	end

	def is_i?
		/\A[-+]?\d+\z/ === self
	end
end

class App < Sinatra::Base
	enable :sessions
	register Sinatra::Flash
	
	helpers do
		def display(file)
			slim file
		end
	end
	
	# helpers Sinatra::Streaming
	
	db = SQLite3::Database.open('db/database.sqlite')
	# $user = false
	# $mod = false
	# $admin = false

	before do
		if @title.nil?
			@title = "ITG Forums"
		end

		if session[:username]
			@user = session[:username]
			db.execute("UPDATE accounts SET last_active = (SELECT datetime('now')) WHERE username = ?", session[:username])
			rank = db.execute("SELECT rank FROM accounts WHERE username = ?", session[:username]).first.first
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
		@latest_posts = []
		for subforum in @subforums
			threads = db.execute("SELECT * FROM threads WHERE subforum = ?", subforum.first)
			posts = []
			for thread in threads
				thread_post = db.execute("SELECT thread, owner, date FROM posts WHERE thread = ? ORDER BY date DESC LIMIT 1", thread.first).first
				if thread_post.nil?
					posts.push([thread[0], thread[1], thread[3], thread[4], thread[6]])
				else
					posts.push([thread[0], thread[1], thread_post[1], thread[4], thread_post[2]])
				end
			end
			@latest_posts.push(posts.last)
		end

		slim :index
	end

	get '/activity' do
		posts = []
		threads = db.execute("SELECT * FROM threads ORDER BY date DESC")
		for thread in threads
			thread_posts = db.execute("SELECT thread, owner, date FROM posts WHERE thread = ? ORDER BY date DESC", thread.first)
			thread_permission = db.execute("SELECT permission FROM forums WHERE id = (SELECT forum FROM subforums WHERE id = ?)", thread[4]).first.first
			if thread_posts.empty?
				posts.push([thread[0], thread[1], thread[3], thread[4], thread[6], thread_permission])
			else
				for post in thread_posts
					posts.push([thread[0], thread[1], post[1], thread[4], post[2], thread_permission])
				end
			end
		end
		@latest_posts = posts.sort_by { |s| DateTime.parse(s[4]).strftime("%F %T") }.reverse

		slim :activity
	end
	
	get '/register' do
		@title = "ITG Forums | Register"
		if session[:username]
			flash[:error] = "You are already logged in"
			redirect '/'
		end
		slim :register
	end
	
	post '/register' do
		redirect '/' if session[:username]
		username = params['username'].downcase
		password = params['password']
		email = params['email'].downcase
		encrypted_pass = BCrypt::Password.create(password)
		username_check = db.execute("SELECT username FROM accounts WHERE username = ?", username).first 
		email_check = db.execute("SELECT email FROM accounts WHERE email = ?", email).first
		
		session[:register_username] = username
		session[:register_email] = email

		if !username_check.nil?
			flash[:error] = "Username already exists"
			redirect back
		elsif !email_check.nil?
			flash[:error] = "Email address is already in use"
			redirect back
		elsif !/^[a-zA-Z0-9_]\w{2,15}$/.match(username)
			flash[:error] = "Username may only contain characters (A-Z), numbers (0-9), underscores and be 3-16 characters long"
			redirect back
		elsif !/\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.match(email)
			flash[:error] = "You must enter a valid email address."
			redirect back
		elsif email.length > 254
			flash[:error] = "Email may not exceed 254 characters."
		elsif password.length < 6 || password.length > 64
			flash[:error] = "Password must be 6-64 characters long."
			redirect back
		else
			db.execute("INSERT INTO accounts (username, encrypted_pass, email) VALUES (?, ?, ?)", username, encrypted_pass, email)
			session.delete(:register_username)
			session.delete(:register_email)
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
		remember = params['remember']
		credentials = db.execute("SELECT username, encrypted_pass, picture FROM accounts WHERE username = ?", username).first
		if credentials.nil?
			flash[:error] = "Invalid username or password"
			redirect back
		else
			encrypted_pass = BCrypt::Password.new(credentials[1])
			if (credentials.first.downcase == username.downcase) && (encrypted_pass == password)
				session[:username] = username
				session.options[:expire_after] = 2592000 unless remember.nil?
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
			email_check = db.execute("SELECT email FROM accounts WHERE email = ?", new_email).first
			if !email_check.nil?
				flash[:error] = "Email address is already in use."
				redirect back
			elsif new_email.length > 254
				flash[:error] = "Email address may not exceed 254 characters."
				redirect back
			elsif !/\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.match(new_email)
				flash[:error] = "You must enter a valid email address."
				redirect back
			else
				db.execute("UPDATE accounts SET email = ? WHERE username = ?", new_email, session[:username])
				flash[:success] = "Email updated!"
				redirect back
			end
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
				if new_password.length < 6 || new_password.length > 64
					flash[:error] = "New password must be 6-64 characters long."
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
			thread_count = db.execute("SELECT COUNT(owner) FROM threads WHERE owner = ?", username).first.first
			post_count = db.execute("SELECT COUNT(owner) FROM posts WHERE owner = ?", username).first.first
			total_post_count = thread_count + post_count
			@account.push(total_post_count)
		rescue
			session[:url] = request.fullpath
			redirect '/not_found'
		end
		slim :profile
	end

	post '/profile/update-picture' do
		username = params[:username]
		if session[:username] == username || @admin
			unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
				flash[:error] = "No file selected"
			end
			
			name = name.split(".") unless !name.include?(".")
			extension = name[1].downcase
			accepted_extensions = ["png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "svg", "webp"]
			# STDERR.puts "Uploading file, original name #{name.inspect}"
			if accepted_extensions.include?(extension)
				if tmpfile.length > 5000000
					flash[:error] = "File size exceeds 5MB"
					redirect back
				end

				Dir.glob("public/uploads/profile-picture/#{username}.*").each do |file|
					File.delete(file)
				end

				File.open("public/uploads/profile-picture/#{username}.#{extension}", 'wb') do |file|
					file.write(tmpfile.read)
				end
				unless extension == "gif" || extension == "svg"
					image = Magick::Image.read("public/uploads/profile-picture/#{username}.#{extension}").first
					image.change_geometry!("128x128") do |cols, rows, img|
						newimg = img.resize(cols, rows)
						newimg.write("public/uploads/profile-picture/#{username}.#{extension}")
					end
				end

				db.execute("UPDATE accounts SET picture = ? WHERE username = ?", "/uploads/profile-picture/#{username}.#{extension}", username)
				session[:profile_picture] = "/uploads/profile-picture/#{username}.#{extension}" if session[:username] == username
				
				flash[:success] = "Profile picture updated successfully"
				redirect back
			else
				flash[:error] = "Unsupported file format. We accept png, jpg, gif, bmp, tif, svg and webp."
				redirect back
			end
		else
			session[:denied] = "You don't have permission to update someone else's profile picture."
			redirect '/denied'
		end
	end
	
	get '/subforum/:id/new' do
		@title = "ITG Forums | New thread"
		@id = params['id']
		forum = db.execute("SELECT forum FROM subforums WHERE id = ?", @id).first.first
		permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum).first.first

		if @admin
			unless permission <= 3
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
		elsif @mod
			unless permission <= 2
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
		elsif @user
			unless permission <= 1
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
		else
			session[:denied] = "You must be logged in to create a new thread."
			redirect '/denied'
		end

		slim :new_thread
	end

	post '/thread/new' do
		id = params['id']
		title = params['title']
		text = params['text']
		# content = [title, text]
		session[:thread_title] = title
		session[:thread_text] = text
		# response.set_cookie 'new_thread', :value => content, :max_age => '2592000'

		begin
			forum = db.execute("SELECT forum FROM subforums WHERE id = ?", id).first.first
			permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum).first.first
		rescue
			session[:url] = "/subforum/#{id}"
			redirect '/not_found'
		end

		if @admin
			unless permission <= 3
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
		elsif @mod
			unless permission <= 2
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
		elsif @user
			unless permission <= 1
				session[:denied] = "You don't have permission to create a new thread in this subforum."
				redirect '/denied'
			end
		else
			session[:denied] = "You must be logged in to create a new thread."
			redirect '/denied'
		end

		begin
			if title.empty? || title.blank?
				flash[:error] = "Title may not be empty."
				redirect back
			elsif title.length > 40
				flash[:error] = "Title may not exceed 40 characters."
				redirect back
			elsif text.length < 5
				flash[:error] = "Message is too short. Please do not post unnecessary spam."
				redirect back
			elsif text.length > 10000
				flash[:error] = "Message may not exceed 10000 characters."
				redirect back
			else
				db.execute("INSERT INTO threads (title, text, owner, subforum) VALUES (?, ?, ?, ?)", title, text, session[:username], id)
				thread_id = db.execute("SELECT last_insert_rowid() FROM threads").first.first
				session.delete(:thread_title)
				session.delete(:thread_text)
				flash[:success] = "Thread created successfully!"
				redirect "/thread/#{thread_id}"
			end
		rescue Exception => ex
			open('error_log.log', 'a') do |file|
				file.puts "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{session[:username]}: #{ex.message}"
			end

			flash[:error] = "Failed to create thread. If this is a recurring issue, please contact support for assistance."
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

			threads = db.execute("SELECT * FROM threads WHERE subforum = ? ORDER BY date DESC", id)
			@thread_count = threads.length
			if @thread_count > 10
				threads_sliced = threads.each_slice(10).to_a
				@page_count = threads_sliced.length
				if params['page'].nil?
					page = 0
					redirect "/subforum/#{id}?page=1"
				else
					page = params['page'].to_i - 1
				end
				begin
					@threads = threads_sliced[page]
					raise "Not found" if @threads.nil?
				rescue
					session[:url] = request.fullpath
					redirect '/not_found'
				end
			else
				@threads = threads
			end
			# test = @threads.each_slice(15).to_a

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

	post '/thread/:id/rating/up' do
		id = params[:id]
		db.execute("UPDATE threads SET rating = rating + 1 WHERE id = ?", id)
		post_owner = db.execute("SELECT owner FROM threads WHERE id = ?", id).first
		db.execute("UPDATE accounts SET reputation = reputation + 1 WHERE username = ?", post_owner)
	end

	post '/thread/:id/rating/down' do
		id = params[:id]
		db.execute("UPDATE threads SET rating = rating - 1 WHERE id = ?", id)
		post_owner = db.execute("SELECT owner FROM threads WHERE id = ?", id).first
		db.execute("UPDATE accounts SET reputation = reputation - 1 WHERE username = ?", post_owner)
	end

	post '/post/:id/rating/up' do
		id = params[:id]
		db.execute("UPDATE posts SET rating = rating + 1 WHERE id = ?", id)
		post_owner = db.execute("SELECT owner FROM posts WHERE id = ?", id).first
		db.execute("UPDATE accounts SET reputation = reputation + 1 WHERE username = ?", post_owner)
	end

	post '/post/:id/rating/down' do
		id = params[:id]
		db.execute("UPDATE posts SET rating = rating - 1 WHERE id = ?", id)
		post_owner = db.execute("SELECT owner FROM posts WHERE id = ?", id).first
		db.execute("UPDATE accounts SET reputation = reputation - 1 WHERE username = ?", post_owner)
	end

	post '/thread/reply' do
		if session[:username]
			id = params['id']
			message = params['message']
			session[:reply_msg] = message
			# response.set_cookie 'reply_message', :value => message, :max_age => '2592000'
			# response.delete_cookie 'reply_message'

			begin
				user_rank = db.execute("SELECT rank FROM accounts WHERE username = ?", session[:username]).first.first
				subforum_id = db.execute("SELECT subforum FROM threads WHERE id = ?", id).first.first
				forum_id = db.execute("SELECT forum FROM subforums WHERE id = ?", subforum_id).first.first
				forum_permission = db.execute("SELECT permission FROM forums WHERE id = ?", forum_id).first.first
				if user_rank >= forum_permission
					if message.empty? || message.blank?
						flash[:error] = "Message may not be empty."
						redirect back
					elsif message.length < 10
						flash[:error] = "Message is too short. Please do not post unnecessary spam."
						redirect back
					elsif message.length > 10000
						flash[:error] = "Message may not exceed 10000 characters."
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
				session[:url] = "/thread/#{id}"
				redirect '/not_found'
			end
		else
			session[:denied] = "You must login before making a post."
			redirect '/denied'
		end
	end

	# get '/activity' do
	# 	# @posts = db.execute("")
	# 	"Not implemented yet"
	# end

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

	get '/admin' do
		unless @admin
			session[:denied] = "You do not have permission to view this page."
			redirect '/denied'
		end
		@forum_categories = db.execute("SELECT * FROM forums ORDER BY permission ASC")
		@subforums = db.execute("SELECT * FROM subforums ORDER BY forum ASC")

		slim :admin
	end

	post '/admin/forum/new' do
		unless @admin
			session[:denied] = "You do not have permission to create a new forum category."
			redirect '/denied'
		end

		name = params['name']
		permission = params['permission'].to_i

		if name.empty? || name.blank?
			flash[:error] = "Name must not be empty."
			redirect back
		elsif name.length > 40
			flash[:error] = "Name must not exceed 40 characters."
			redirect back
		elsif permission.nil?
			flash[:error] = "You must select a permission."
			redirect back
		elsif permission < 0 || permission > 3
			flash[:error] = "Invalid permission."
			redirect back
		else
			db.execute("INSERT INTO forums (forum_name, permission) VALUES (?, ?)", name, permission)
			flash[:success] = "Forum category has been created!"
			redirect back
		end
	end

	post '/admin/forum/modify' do
		unless @admin
			session[:denied] = "You do not have permission to modify forum categories."
			redirect '/denied'
		end

		modify = params['modify']
		delete = params['delete']
		forum_id = params['forum'].to_i
		if modify
			name = params['name']
			permission = params['permission'].to_i
			if name.empty? || name.blank?
				flash[:error] = "Forum name must not be empty."
				redirect back
			elsif permission.nil?
				flash[:error] = "You must select a permission."
				redirect back
			elsif permission < 0 || permission > 3
				flash[:error] = "Invalid permission."
				redirect back
			else
				db.execute("UPDATE forums SET forum_name = ?, permission = ? WHERE id = ?", name, permission, forum_id)
			end
			flash[:success] = "Forum has been updated!"
			redirect back
		elsif delete
			subforums = db.execute("SELECT * FROM subforums WHERE forum = ?", forum_id)
			for subforum in subforums
				threads = db.execute("SELECT * FROM threads WHERE subforum = ?", subforum[0])
				for thread in threads
					db.execute("DELETE FROM posts WHERE thread = ?", thread[0])
				end
				db.execute("DELETE FROM threads WHERE subforum = ?", subforum[0])
			end
			db.execute("DELETE FROM subforums WHERE forum = ?", forum_id)
			db.execute("DELETE FROM forums WHERE id = ?", forum_id)

			flash[:success] = "The forum and all its content have been deleted!"
			redirect back
		end
	end

	post '/admin/subforum/new' do
		unless @admin
			session[:denied] = "You do not have permission to create a new subforum."
			redirect '/denied'
		end

		forum = params['forum']
		name = params['name']
		description = params['description']
		if forum.nil?
			flash[:error] = "You must select a forum category."
			redirect back
		elsif name.empty? || name.blank?
			flash[:error] = "Subforum name must not be empty."
			redirect back
		else
			db.execute("INSERT INTO subforums (name, description, forum) VALUES (?, ?, ?)", name, description, forum)
		end

		flash[:success] = "Subforum has been created!"
		redirect back
	end
	
	post '/admin/subforum/modify' do
		unless @admin
			session[:denied] = "You do not have permission to modify subforums."
			redirect '/denied'
		end

		subforum = params['subforum']
		name = params['name']
		description = params['description']

		if subforum.nil?
			flash[:error] = "You must select a subforum."
			redirect back
		elsif name.empty? || name.blank?
			flash[:error] = "Subforum name must not be empty."
			redirect back
		else
			db.execute("UPDATE subforums SET name = ?, description = ? WHERE id = ?", name, description, subforum)
			flash[:success] = "Subforum has been updated!"
			redirect back
		end
	end
end