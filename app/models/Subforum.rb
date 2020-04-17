class Subforum < Database
    attr_reader :id
    attr_accessor :name, :description, :forum_id

    def initialize(id)
        subforum = @@db.execute("SELECT * FROM subforums WHERE id = ?", id).first
        @id = subforum[0]
        @name = subforum[1]
        @description = subforum[2]
        @forum_id = subforum[3]
    end

    def self.create(name, description, forum_id)
        @@db.execute("INSERT INTO subforums (name, description, forum) VALUES (?, ?, ?)", name, description, forum_id)
    end

    def self.modify(subforum_id, name, description)
        @@db.execute("UPDATE subforums SET name = ?, description = ? WHERE id = ?", name, description, subforum_id)
    end

    def self.delete(subforum_id)
        threads = @@db.execute("SELECT id FROM threads WHERE subforum = ?", subforum_id)
        for thread in threads
            @@db.execute("DELETE FROM posts WHERE thread = ?", thread.first)
        end
        @@db.execute("DELETE FROM threads WHERE subforum = ?", subforum_id)
        @@db.execute("DELETE FROM subforums WHERE id = ?", subforum_id)
    end

    def self.get_all
        subforums = @@db.execute("SELECT * FROM subforums")

        subforum_objects = []
        for subforum in subforums
            sf = self.new(subforum[0])
            subforum_objects.push sf
        end

        return subforum_objects
    end

    def get_forum_permission
        forum_id = @@db.execute("SELECT forum FROM subforums WHERE id = ?", @id).first.first
        forum_permission = @@db.execute("SELECT permission FROM forums WHERE id = ?", forum_id).first.first

        if forum_permission == 3
            permission = :admin
        elsif forum_permission == 2
            permission = :mod
        elsif forum_permission == 1
            permission = :user
        else
            permission = :all
        end

        return permission
    end

    def get_threads
        threads = @@db.execute("SELECT id FROM threads WHERE subforum = ? ORDER BY date DESC", self.id)
        
        thread_objects = []
        for thread in threads
            t = Thread_.new(thread[0])
            thread_objects.push t
        end

        return thread_objects
    end

    def get_threads_with_pagination(page_length)
        return nil if page_length < 1

        threads = @@db.execute("SELECT id FROM threads WHERE subforum = ? ORDER BY date DESC", self.id)
        thread_objects = []
        for thread in threads
            t = Thread_.new(thread[0])
            thread_objects.push t
        end

        threads_sliced = thread_objects.each_slice(page_length).to_a
        return threads_sliced
    end
    
    def get_latest
        latest_thread = @@db.execute("SELECT * FROM threads WHERE subforum = ? ORDER BY date DESC LIMIT 1", self.id).first
        latest_posts = @@db.execute("SELECT * FROM posts GROUP BY thread ORDER BY date DESC")

        # Assume subforum has no posts - indicates there might only be a thread
        no_posts = true
        for post in latest_posts
            post_thread = Thread_.new(post[1])
        
            if post_thread.subforum.id == self.id
                # Compare dates and determine if thread is newer than post
                if [latest_thread[6], post[5]].max == latest_thread[6]
                    thread_is_newer = true
                else
                    latest_post = post
                end

                no_posts = false
                
                break
            end
        end

        if thread_is_newer
            return Thread_.new(latest_thread[0])
        else
            # There is a thread but no posts
            if !latest_thread.nil? && no_posts
                return Thread_.new(latest_thread[0])
            # The subforum is empty
            elsif latest_post.nil?
                return nil
            # Post is newest
            else
                return Post.new(latest_post[0])
            end
        end
    end
end