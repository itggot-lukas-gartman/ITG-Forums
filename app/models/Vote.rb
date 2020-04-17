class Vote < Database
    def self.has_voted?(thread_id, post_id, username)
        vote_check = @@db.execute("SELECT * FROM votes WHERE thread = ? AND post = ? AND account = ?", thread_id, post_id, username).first
        vote_check.nil? ? false : true
    end

    def self.upvote(thread_id, post_id, username)
        @@db.execute("INSERT INTO votes (thread, post, account, vote) VALUES (?, ?, ?, ?)", thread_id, post_id, username, 1)
        if post_id == 0
            @@db.execute("UPDATE threads SET rating = rating + 1 WHERE id = ?", thread_id)
            post_owner = @@db.execute("SELECT owner FROM threads WHERE id = ?", thread_id).first
        else
            @@db.execute("UPDATE posts SET rating = rating + 1 WHERE id = ?", post_id)
            post_owner = @@db.execute("SELECT owner FROM posts WHERE id = ?", post_id).first
        end
		@@db.execute("UPDATE accounts SET reputation = reputation + 1 WHERE username = ?", post_owner)
    end

    def self.downvote(thread_id, post_id, username)
        @@db.execute("INSERT INTO votes (thread, post, account, vote) VALUES (?, ?, ?, ?)", thread_id, post_id, username, -1)
        if post_id == 0
            @@db.execute("UPDATE threads SET rating = rating - 1 WHERE id = ?", thread_id)
            post_owner = @@db.execute("SELECT owner FROM threads WHERE id = ?", thread_id).first
        else
            @@db.execute("UPDATE posts SET rating = rating - 1 WHERE id = ?", post_id)
            post_owner = @@db.execute("SELECT owner FROM posts WHERE id = ?", post_id).first
        end
		@@db.execute("UPDATE accounts SET reputation = reputation - 1 WHERE username = ?", post_owner)
    end
end