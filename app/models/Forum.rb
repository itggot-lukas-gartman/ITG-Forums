class Forum < Database
    attr_reader :id
    attr_accessor :name, :permission, :subforums

    def initialize(id)
        forum = @@db.execute("SELECT * FROM forums WHERE id = ?", id).first
        @id = forum[0]
        @name = forum[1]

        case forum[2]
        when 3
            @permission = :admin
        when 2
            @permission = :mod
        when 1
            @permission = :user
        when 0
            @permission = :all
        end

        subforums = @@db.execute("SELECT id FROM subforums WHERE forum = ?", self.id)
        subforum_objects = []
        for subforum in subforums
            sf = Subforum.new(subforum[0])
            subforum_objects.push sf
        end
        @subforums = subforum_objects
    end

    def self.create(name, permission)
        @@db.execute("INSERT INTO forums (forum_name, permission) VALUES (?, ?)", name, permission) 
    end

    def self.modify(forum_id, name, permission)
        @@db.execute("UPDATE forums SET forum_name = ?, permission = ? WHERE id = ?", name, permission, forum_id)
    end

    def self.delete(forum_id)
        subforums = @@db.execute("SELECT * FROM subforums WHERE forum = ?", forum_id)
        for subforum in subforums
            threads = @@db.execute("SELECT * FROM threads WHERE subforum = ?", subforum[0])
            for thread in threads
                @@db.execute("DELETE FROM posts WHERE thread = ?", thread[0])
            end
            @@db.execute("DELETE FROM threads WHERE subforum = ?", subforum[0])
        end
        @@db.execute("DELETE FROM subforums WHERE forum = ?", forum_id)
        @@db.execute("DELETE FROM forums WHERE id = ?", forum_id)
    end

    def self.get_all(options = nil)
        if options
            if options[:order_by]
                forums = @@db.execute("SELECT * FROM forums ORDER BY #{options[:order_by]} ASC")
            end
        else
            forums = @@db.execute("SELECT * FROM forums")
        end

        forum_objects = []
        for forum in forums
            f = self.new(forum[0])
            forum_objects.push f
        end

        return forum_objects
    end

    # might have to name it self.get_subforums
    # def get_subforums
    #     subforums = @@db.execute("SELECT id FROM subforums WHERE forum = ?", self.id)

    #     subforum_objects = []
    #     for subforum in subforums
    #         sf = Subforum.new(subforum[0])
    #         subforum_objects.push sf
    #     end

    #     return subforum_objects
    # end
end