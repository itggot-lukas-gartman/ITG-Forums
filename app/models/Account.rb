class Account < Database
    attr_reader :id, :username, :register_date
    attr_accessor :email, :picture, :last_active, :reputation, :rank, :post_count

    def initialize(username)
        if username.nil?
            @id = 0
            @username = "Guest"
            @picture = "/uploads/profile-picture/default.svg"
            @rank = :all
        else
            user = @@db.execute("SELECT * FROM accounts WHERE username = ?", username).first
            @id = user[0]
            @username = user[1]
            @email = user[3]
            @picture = user[5]
            @last_active = DateTime.parse(user[6])
            @register_date = DateTime.parse(user[7])
            @reputation = user[8]
            @post_count = get_post_count(username)

            case user[4]
            when 3
                @rank = :admin
            when 2
                @rank = :mod
            when 1
                @rank = :user
            when -1
                @rank = :banned
            end
        end
    end

    def self.create(username, password, email)
        bcrypt_password = BCrypt::Password.create(password)
		@@db.execute("INSERT INTO accounts (username, encrypted_pass, email) VALUES (?, ?, ?)", username, bcrypt_password, email)
    end

    def self.modify(old_username, new_username, email, password, rank, picture)
        @@db.execute("UPDATE threads SET owner = ? WHERE owner = ?", new_username, old_username)
        @@db.execute("UPDATE posts SET owner = ? WHERE owner = ?", new_username, old_username)

        if password.empty? || password.blank?
            @@db.execute("UPDATE accounts SET username = ?, email = ?, rank = ?, picture = ? WHERE username = ?", new_username, email, rank, picture, old_username)
        else
            encrypted_pass = BCrypt::Password.create(password)
            @@db.execute("UPDATE accounts SET username = ?, email = ?, encrypted_pass = ?, rank = ?, picture = ? WHERE username = ?", new_username, email, encrypted_pass, rank, picture, old_username)
        end
    end

    def self.delete(username)
        threads = @@db.execute("SELECT id FROM threads WHERE owner = ?", username)
        for thread in threads
            @@db.execute("DELETE FROM posts WHERE thread = ?", thread.first)
        end
        @@db.execute("DELETE FROM threads WHERE owner = ?", username)
        @@db.execute("DELETE FROM posts WHERE owner = ?", username)
        @@db.execute("DELETE FROM accounts WHERE username = ?", username)
    end

    def self.get_all
        accounts = @@db.execute("SELECT username FROM accounts")

        account_objects = []
        for account in accounts
            a = self.new(account[0])
            account_objects.push a
        end

        return account_objects
    end

    def self.auth(username, password)
        user_info = @@db.execute("SELECT username, encrypted_pass FROM accounts WHERE username = ?", username).first
        if user_info.nil?
            return false
        else
            encrypted_password = user_info[1]
			bcrypt_password = BCrypt::Password.new(encrypted_password)
			bcrypt_password == password ? true : false
		end
    end

    def self.username_available?(username)
        username_check = @@db.execute("SELECT username FROM accounts WHERE username = ?", username)
        username_check[0].nil? ? true : false
    end

    def self.email_available?(email)
        email_check = @@db.execute("SELECT email FROM accounts WHERE email = ?", email)
        email_check[0].nil? ? true : false
    end

    def get_post_count(username)
        thread_count = @@db.execute("SELECT COUNT(owner) FROM threads WHERE owner = ?", username).first.first
        post_count = @@db.execute("SELECT COUNT(owner) FROM posts WHERE owner = ?", username).first.first
        total_post_count = thread_count + post_count
        return total_post_count
    end

    def self.update_picture(username, path)
        @@db.execute("UPDATE accounts SET picture = ? WHERE username = ?", path, username)
    end

    def update_email(email)
        @@db.execute("UPDATE accounts SET email = ? WHERE username = ?", email, self.username)
    end

    def update_password(old_password, new_password)
        db_pass = @@db.execute("SELECT encrypted_pass FROM accounts WHERE username = ?", self.username).first.first
        encrypted_pass = BCrypt::Password.new(db_pass)

        if encrypted_pass == old_password
            new_encrypted_pass = BCrypt::Password.create(new_password)
            @@db.execute("UPDATE accounts SET encrypted_pass = ? WHERE username = ?", new_encrypted_pass, self.username)
            return true
        else
            return false
        end
    end

    def update_activity
        @@db.execute("UPDATE accounts SET last_active = (SELECT datetime('now')) WHERE username = ?", self.username)
    end

    def has_rank?(rank)
        if rank == :all
            return true
        elsif self.rank == :admin  # admins have access to everything
            return true
        elsif self.rank == :mod
            return true if [:user, :mod].include? rank
        elsif self.rank == rank
            return true
        else
            return false
        end
    end
end