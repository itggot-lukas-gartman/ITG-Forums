class Thread_ < Database
    attr_reader :id, :owner, :date
    attr_accessor :title, :text, :subforum, :rating

    def initialize(id)
        thread = @@db.execute("SELECT * FROM threads WHERE id = ?", id).first
        @id = thread[0]
        @title = thread[1]
        @text = thread[2]
        @owner = Account.new(thread[3])
        @subforum = Subforum.new(thread[4])
        @rating = thread[5]
        @date = DateTime.parse(thread[6])
    end

    def self.create(title, text, owner, subforum_id)
        forum = @@db.execute("SELECT forum FROM subforums WHERE id = ?", subforum_id).first.first
        permission = @@db.execute("SELECT permission FROM forums WHERE id = ?", forum).first.first
        @@db.execute("INSERT INTO threads (title, text, owner, subforum) VALUES (?, ?, ?, ?)", title, text, owner, subforum_id)
        thread_id = @@db.execute("SELECT last_insert_rowid() FROM threads").first.first
        return self.new(thread_id)
    end

    def self.get_all(options = nil)
        if options
            if options[:new_first]
                threads = @@db.execute("SELECT id FROM threads ORDER BY date DESC")
            end
        else
            threads = @@db.execute("SELECT id FROM threads")
        end

        thread_objects = []
        for thread in threads
            t = self.new(thread[0])
            thread_objects.push t
        end

        return thread_objects
    end

    def self.get_permission(thread_id)
        subforum_id = @@db.execute("SELECT subforum FROM threads WHERE id = ?", thread_id).first.first
        forum_id = @@db.execute("SELECT forum FROM subforums WHERE id = ?", subforum_id).first.first
        forum = Forum.new(forum_id)
        return forum.permission
    end

    def get_permission
        subforum_id = @@db.execute("SELECT subforum FROM threads WHERE id = ?", self.id).first.first
        forum_id = @@db.execute("SELECT forum FROM subforums WHERE id = ?", subforum_id).first.first
        forum = Forum.new(forum_id)
        return forum.permission
    end
    
    def get_posts(options = nil)
        if options
            if options[:new_first]
                posts = @@db.execute("SELECT id FROM posts WHERE thread = ? ORDER BY date DESC", self.id)
            end
        else
            posts = @@db.execute("SELECT id FROM posts WHERE thread = ?", self.id)
        end

        post_objects = []
        for post in posts
            p = Post.new(post[0])
            post_objects.push p
        end

        return post_objects
    end

    def get_latest_post
        post = @@db.execute("SELECT id FROM posts WHERE thread = ? ORDER BY date DESC LIMIT 1").first
        if post.nil?
            return nil
        else
            return Post.new(post[0])
        end
    end
end