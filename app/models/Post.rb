class Post < Database
    attr_reader :id, :thread, :owner, :date
    attr_accessor :text, :rating

    def initialize(id)
        post = @@db.execute("SELECT * FROM posts WHERE id = ?", id).first
        @id = post[0]
        @thread = Thread_.new(post[1])
        @text = post[2]
        @owner = Account.new(post[3])
        @rating = post[4]
        @date = DateTime.parse(post[5])
    end

    def self.create(thread_id, message, owner)
        @@db.execute("INSERT INTO posts (thread, text, owner) VALUES (?, ?, ?)", thread_id, message, owner)
    end

    def self.get_thread_id(post_id)
        thread_id = @@db.execute("SELECT thread FROM posts WHERE id = ?", post_id).first
        return thread_id
    end

    def get_permission
        return self.thread.get_permission()
    end
end