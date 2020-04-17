class ApplicationController < Sinatra::Base
	enable :sessions
	register Sinatra::Flash

	configure do
		set :views, "app/views"
		set :public_dir, "public"
	end
	
	helpers do
		def logged_in?
			session[:username].nil? ? false : true
		end
		
		def display(file)
			slim file
		end
	end

	set(:auth) do |*ranks|
		condition do
			unless logged_in? && ranks.any? { |rank| @user.has_rank? rank }
				redirect "/denied"
			end
		end
	end

	before do
		@title ||= "ITG Forums"

		if logged_in?
			begin
				@user = Account.new(session[:username])
				@user.update_activity()
			rescue Exception => ex
				flash[:error] = "An unknown error occurred. Please try again."
				session.destroy
				redirect '/'
			end
		else
			@user = Account.new(nil)
		end
	end

	not_found do
		session[:url] = request.fullpath
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
		@forums = Forum.get_all()

		slim :index
	end

	get '/activity' do
		@activity = []
		threads = Thread_.get_all()

		for thread in threads
			@activity.push thread
			thread_posts = thread.get_posts()
			for post in thread_posts
				@activity.push post
			end
		end

		@activity = @activity.sort_by { |s| s.date.strftime("%F %T") }.reverse!

		slim :activity
	end
	
	get '/register' do
		@title = "ITG Forums | Register"
		if logged_in?
			flash[:error] = "You are already logged in"
			redirect '/'
		end
		slim :register
	end
	
	post '/register' do
		redirect '/' if logged_in?

		username = params['username'].downcase
		password = params['password']
		email = params['email'].downcase

		session[:register_username] = username
		session[:register_email] = email

		errors = []
		errors.push "Username already exists" if !Account.username_available? username
		errors.push "Email address is already in use" if !Account.email_available? email
		errors.push "Username may only contain characters (A-Z), numbers (0-9), underscores and be 3-16 characters long" if !/^[a-zA-Z0-9_]\w{2,15}$/.match(username)
		errors.push "You must enter a valid email address" if !/\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.match(email)
		errors.push "Email may not exceed 254 characters" if email.length > 254
		errors.push "Password must be 6-64 characters long" if password.length < 6 || password.length > 64

		if errors.empty?
			Account.create(username, password, email)
			session.delete(:register_username)
			session.delete(:register_email)
			session[:username] = username
			flash[:success] = "Account registered. Welcome to ITG forums!"
			redirect '/'
		else
			flash[:error] = errors
			redirect back
		end
	end
	
	post '/login' do
		username = params['username'].downcase
		password = params['password']
		remember = params['remember']

		if Account.auth(username, password)
			session[:username] = username
			session.options[:expire_after] = 2592000 unless remember.nil?
		else
			flash[:error] = "Invalid username or password"
		end

		redirect back
	end
	
	get '/logout' do
		if logged_in?
			session.delete(:username)
			redirect '/'
		else
			flash[:error] = "You are not logged in"
			redirect back
		end
	end
	
	
	# Account settings
	get '/settings', :auth => :user do
		slim :settings
	end
	
	post '/settings/email', :auth => :user do
		new_email = params['email']

		errors = []
		errors.push "Email address is already in use." if !Account.email_available? new_email
		errors.push "Email address may not exceed 254 characters." if new_email.length > 254
		errors.push "You must enter a valid email address." if !/\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i.match(new_email)

		if errors.empty?
			@user.update_email(new_email)
			flash[:success] = "Email updated!"
		else
			flash[:error] = errors
		end

		redirect back
	end
	
	post '/settings/password', :auth => :user do
		old_password = params['old_password']
		new_password = params['new_password']
		repeat_password = params['repeat_password']
		
		errors = []
		errors.push "New password must be 6-64 characters long." if new_password.length < 6 || new_password.length > 64
		errors.push "New passwords do not match" if new_password != repeat_password
		
		if errors.empty?
			if @user.update_password(old_password, new_password)
				flash[:success] = "Password has been updated!"
			else
				flash[:error] = "Old password does not match"
			end
		else
			flash[:error] = errors
		end

		redirect back
	end


	# Account profile
	get '/profile/:username' do
		username = params[:username]
		begin
			@account = Account.new(username)
		rescue
			session[:url] = request.fullpath
			not_found()
		end
		slim :profile
	end

	post '/profile/update-picture', :auth => [:user, :admin] do
		username = params[:username]
		unless params[:file] && (tmpfile = params[:file][:tempfile]) && (name = params[:file][:filename])
			flash[:error] = "No file selected"
		end
		
		name = name.split(".") unless !name.include?(".")
		extension = name[1].downcase
		accepted_extensions = ["png", "jpg", "jpeg", "gif", "bmp", "tif", "tiff", "svg", "webp"]
		unless accepted_extensions.include?(extension)
			flash[:error] = "Unsupported file format. We accept png, jpg, gif, bmp, tif, svg and webp."
			redirect back
		end
		
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

		Account.update_picture(username, "/uploads/profile-picture/#{username}.#{extension}")
		
		flash[:success] = "Profile picture updated successfully"
		redirect back
	end

	get '/subforum/:id/new_thread', :auth => :user do
		@title = "ITG Forums | New thread"

		id = params['id']
		@subforum = Subforum.new(id)
		forum_permission = @subforum.get_forum_permission()

		if @user.has_rank? forum_permission
			slim :new_thread
		else
			flash[:error] = "You don't have permission to create a new thread in this subforum."
			redirect back
		end
	end

	post '/thread/new', :auth => :user do
		subforum_id = params['subforum_id']
		title = params['title']
		text = params['text']
		# content = [title, text]
		session[:thread_title] = title
		session[:thread_text] = text
		# response.set_cookie 'new_thread', :value => content, :max_age => '2592000'

		begin
			subforum = Subforum.new(subforum_id)
			forum_permission = subforum.get_forum_permission()
		rescue
			session[:url] = "/subforum/#{subforum_id}"
			not_found()
		end

		unless @user.has_rank? forum_permission
			flash[:error] = "You don't have permission to create a new thread in this subforum." 
			redirect back
		end

		errors = []
		errors.push "Title may not be empty." if title.empty? || title.blank?
		errors.push "Title may not exceed 40 characters." if title.length > 40
		errors.push "Message is too short. Please do not post unnecessary spam." if text.length < 5
		errors.push "Message may not exceed 10000 characters." if text.length > 10000

		unless errors.empty?
			flash[:error] = errors
			redirect back
		end

		begin
			thread = Thread_.create(title, text, @user.username, subforum_id)
		rescue Exception => ex
			open('error_log.log', 'a') do |file|
				file.puts "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{@user.username}: #{ex.message}"
			end

			flash[:error] = "Failed to create thread. If this is a recurring issue, please contact support for assistance."
			redirect back
		end

		session.delete(:thread_title)
		session.delete(:thread_text)
		flash[:success] = "Thread has been created!"
		redirect "/thread/#{thread.id}"
	end

	get '/subforum/:id' do
		subforum_id = params['id']

		begin
			@subforum = Subforum.new(subforum_id)
			@title = "ITG Forums | #{@subforum.name}"
		rescue
			session[:url] = request.fullpath
			not_found()
		end

		forum_permission = @subforum.get_forum_permission()
		unless @user.has_rank? forum_permission
			session[:denied] = "You don't have permission to view this forum."
			redirect '/denied'
		end

		threads = @subforum.get_threads_with_pagination(POSTS_PER_PAGE)
		@page_count = threads.length

		page = params['page']
		if page.nil?
			page = 1
			redirect "/subforum/#{subforum_id}?page=1"
		else
			page = page.to_i
		end

		begin
			@threads = threads[page - 1]
			raise "Not found" if @threads.nil? unless page == 1
		rescue
			session[:url] = request.fullpath
			not_found()
		end

		slim :subforum
	end

	get '/thread/:id' do
		thread_id = params['id']

		begin
			@thread = Thread_.new(thread_id)
		rescue
			session[:url] = request.fullpath
			not_found()
		end

		@title = "ITG Forums | #{@thread.title}"
		
		forum_permission = @thread.subforum.get_forum_permission()
		unless @user.has_rank? forum_permission
			session[:denied] = "You don't have permission to view this forum."
			redirect '/denied'
		end

		@posts = @thread.get_posts()

		slim :thread
	end

	post '/thread/:id/upvote', :auth => :user do
		thread_id = params[:id]
		forum_permission = Thread_.get_permission(thread_id)
		if @user.has_rank? forum_permission
			Vote.upvote(thread_id, 0, @user.username) unless Vote.has_voted?(thread_id, 0, @user.username)
		end
	end

	post '/thread/:id/downvote', :auth => :user do
		thread_id = params[:id]
		forum_permission = Thread_.get_permission(thread_id)
		if @user.has_rank? forum_permission
			Vote.downvote(thread_id, 0, @user.username) unless Vote.has_voted?(thread_id, 0, @user.username)
		end
	end

	post '/post/:id/upvote', :auth => :user do
		post_id = params[:id]
		thread_id = Post.get_thread_id(post_id)
		forum_permission = Thread_.get_permission(thread_id)
		if @user.has_rank? forum_permission
			Vote.upvote(thread_id, post_id, @user.username) unless Vote.has_voted?(thread_id, post_id, @user.username)
		end
	end

	post '/post/:id/downvote', :auth => :user do
		post_id = params[:id]
		thread_id = Post.get_thread_id(post_id)
		forum_permission = Thread_.get_permission(thread_id)
		if @user.has_rank? forum_permission
			Vote.downvote(thread_id, post_id, @user.username) unless Vote.has_voted?(thread_id, post_id, @user.username)
		end
	end

	post '/thread/reply', :auth => :user do
		thread_id = params['thread_id']
		message = params['message']
		session[:reply_msg] = message
		# response.set_cookie 'reply_message', :value => message, :max_age => '2592000'
		# response.delete_cookie 'reply_message'

		begin
			forum_permission = Thread_.get_permission(thread_id)
		rescue
			session[:url] = "/thread/#{thread_id}"
			not_found()
		end

		unless @user.has_rank? forum_permission
			session[:denied] = "You don't have permission to post in this forum."
			redirect '/denied'
		end

		errors = []
		errors.push "Message may not be empty." if message.empty? || message.blank?
		errors.push "Message is too short. Please do not post unnecessary spam." if message.length < 10
		errors.push "Message may not exceed 10000 characters." if message.length > 10000

		unless errors.empty?
			flash[:error] = errors
			redirect back
		end

		Post.create(thread_id, message, @user.username)
		flash[:success] = "Posted successfully!"
		session.delete(:reply_msg)
		redirect back
	end

	get '/users' do
		@title = "ITG Forums | Users"
		accounts = Account.get_all()

		@admins = []
		@mods = []
		@users = []
		
		for account in accounts
			if account.rank == :admin
				@admins.push(account)
			elsif account.rank == :mod
				@mods.push(account)
			else
				@users.push(account)
			end
		end

		slim :users
	end

	get '/admin', :auth => :admin do
		@forums = Forum.get_all(order_by: "permission")
		@accounts = Account.get_all()

		slim :admin
	end

	post '/admin/forum/new', :auth => :admin do
		name = params['name']
		permission = params['permission']

		case permission
		when "admin"
			permission_value = 3
		when "mod"
			permission_value = 2
		when "user"
			permission_value = 1
		when "all"
			permission_value = 0
		end

		errors = []
		errors.push "Name must not be empty." if name.empty? || name.blank?
		errors.push "Name must not exceed 40 characters." if name.length > 40
		errors.push "You must select a permission." if permission.nil?
		errors.push "Invalid permission." if permission_value < 0 || permission_value > 3

		unless errors.empty?
			flash[:error] = errors
			redirect back
		end
		
		Forum.create(name, permission_value)
		flash[:success] = "Forum category has been created!"
		redirect back
	end

	post '/admin/forum/modify', :auth => :admin do
		modify = params['modify']
		delete = params['delete']
		forum_id = params['forum'].to_i
		if modify
			name = params['name']
			permission = params['permission']

			case permission
			when "admin"
				permission_value = 3
			when "mod"
				permission_value = 2
			when "user"
				permission_value = 1
			when "all"
				permission_value = 0
			end

			errors = []
			errors.push "Forum name must not be empty." if name.empty? || name.blank?
			errors.push "You must select a permission." if permission.nil?
			errors.push "Invalid permission." if permission_value < 0 || permission_value > 3
			
			unless errors.empty?
				flash[:error] = errors
				redirect back
			end

			Forum.modify(forum_id, name, permission_value)
			flash[:success] = "Forum has been updated!"
			redirect back
		elsif delete
			Forum.delete(forum_id)
			flash[:success] = "The forum and all its content have been deleted!"
			redirect back
		end
	end

	post '/admin/subforum/new', :auth => :admin do
		forum_id = params['forum']
		name = params['name']
		description = params['description']

		errors = []
		errors.push "You must select a forum category." if forum_id.nil?
		errors.push "Subforum name must not be empty." if name.empty? || name.blank?

		unless errors.empty?
			flash[:error] = errors
			redirect back
		end

		Subforum.create(name, description, forum_id)
		flash[:success] = "Subforum has been created!"
		redirect back
	end
	
	post '/admin/subforum/modify', :auth => :admin do
		modify = params['modify']
		delete = params['delete']

		subforum_id = params['subforum']
		if subforum_id.nil?
			flash[:error] = "You must select a subforum."
			redirect back
		end

		if modify
			name = params['name']
			description = params['description']

			if name.empty? || name.blank?
				flash[:error] = "Subforum name must not be empty."
				redirect back
			end

			Subforum.modify(subforum_id, name, description)
			flash[:success] = "Subforum has been updated!"
			redirect back
		elsif delete
			Subforum.delete(subforum_id)
			flash[:success] = "Subforum and all its content has been deleted!"
			redirect back
		end
	end

	post '/admin/account/modify', :auth => :admin do
		update = params['update']
		delete = params['delete']
		account_name = params['account']

		if update
			username = params['username']
			email = params['email']
			new_password = params['new_password']
			profile_picture = params['profile_picture']
			rank = params['rank']

			case rank
			when "admin"
				rank_value = 3
			when "mod"
				rank_value = 2
			when "user"
				rank_value = 1
			when "all"
				rank_value = 0
			end

			errors = []
			errors.push "You must select an account." if account_name.nil?
			errors.push "Username must not be empty." if username.empty? || username.blank?
			errors.push "Email must not be empty." if email.empty? || email.blank?
			errors.push "Invalid rank." if rank_value < 0 || rank_value > 3

			unless errors.empty?
				flash[:error] = errors
				redirect back
			end

			Account.modify(account_name, username, email, new_password, rank_value, profile_picture)			

			filename = Dir.glob("public/uploads/profile-picture/#{account_name}.*").first
			filename = filename.split(".")
			File.rename("#{filename[0]}.#{filename[-1]}", "public/uploads/profile-picture/#{username}.#{filename[-1]}")

			if account_name == @user.username
				flash[:error] = "Changing your own account requires you to log back in."
				session.destroy
				redirect '/'
			end

			flash[:success] = "Account has been updated!"
			redirect back
		elsif delete
			if account_name.nil?
				flash[:error] = "You must select an account."
				redirect back
			end

			account = Account.new(account_name)
			profile_picture = account.picture

			unless profile_picture == "/uploads/profile-picture/default.svg"
				File.delete("public/#{profile_picture}") if File.exist?("public/#{profile_picture}")
			end

			Account.delete(account_name)
			flash[:success] = "Account has been deleted!"
			redirect back
		else
			flash[:error] = "Invalid option."
			redirect back
		end
	end


	# API's
    get '/api/subforum/:subforum', :auth => :admin do
		subforum_id = params['subforum']
		subforum = Subforum.new(subforum_id)

		json = {
			'id' => subforum.id,
			'name' => subforum.name,
			'description' => subforum.description,
			'forum' => subforum.forum_id,
			'permission' => subforum.get_forum_permission()
		}
		return JSON[json]
	end

    get '/api/forum/:forum', :auth => :admin do
		forum_id = params['forum']
		forum = Forum.new(forum_id)

		json = {
			'id' => forum.id,
			'forum_name' => forum.name,
			'permission' => forum.permission
		}
		return JSON[json]
	end

    get '/api/profile/:user', :auth => :admin do
		user = params['user']
		account = Account.new(user)
		
		json = {
			'id' => account.id,
			'username' => account.username,
			'email' => account.email,
			'rank' => account.rank,
			'picture' => account.picture,
			'last_active' => account.last_active,
			'register_date' => account.register_date,
			'reputation' => account.reputation
		}
		return JSON[json]
	end
end